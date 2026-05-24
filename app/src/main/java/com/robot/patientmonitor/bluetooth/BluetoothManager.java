package com.robot.patientmonitor.bluetooth;

import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Singleton Bluetooth manager for HC-05 Classic communication.
 *
 * - Keeps socket alive across activity transitions.
 * - Reads InputStream continuously on a background thread.
 * - Buffers bytes until \n, strips \r, emits complete lines.
 * - Posts callbacks to UI thread via mainHandler.
 * - Activities register/unregister listeners in onResume/onPause.
 */
public class BluetoothManager {

    private static final String TAG = "BT_MANAGER";
    private static final UUID SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    private static BluetoothManager instance;

    private final BluetoothAdapter bluetoothAdapter;
    private BluetoothSocket socket;
    private ReadThread readThread;
    private OutputStream outStream;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    // Connection state
    public enum ConnectionStatus { DISCONNECTED, CONNECTING, CONNECTED }
    private volatile ConnectionStatus status = ConnectionStatus.DISCONNECTED;

    // Listeners — set by the currently visible Activity
    private volatile OnMessageReceivedListener messageListener;
    private volatile OnStatusChangedListener statusListener;

    public interface OnMessageReceivedListener {
        void onMessageReceived(String message);
    }
    public interface OnStatusChangedListener {
        void onStatusChanged(ConnectionStatus status);
    }

    // ── Singleton ──────────────────────────────────────────────────────
    private BluetoothManager() {
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
    }

    public static synchronized BluetoothManager getInstance() {
        if (instance == null) instance = new BluetoothManager();
        return instance;
    }

    // ── Public API ─────────────────────────────────────────────────────
    public ConnectionStatus getStatus() { return status; }

    public void setMessageListener(OnMessageReceivedListener l) {
        this.messageListener = l;
    }

    public void setStatusListener(OnStatusChangedListener l) {
        this.statusListener = l;
        if (l != null) mainHandler.post(() -> l.onStatusChanged(status));
    }

    /** Remove listeners (call from onPause to avoid leaking Activities). */
    public void clearListeners() {
        this.messageListener = null;
        this.statusListener  = null;
    }

    @SuppressLint("MissingPermission")
    public List<BluetoothDevice> getPairedDevices() {
        List<BluetoothDevice> list = new ArrayList<>();
        if (bluetoothAdapter != null) {
            try {
                Set<BluetoothDevice> bonded = bluetoothAdapter.getBondedDevices();
                if (bonded != null) list.addAll(bonded);
            } catch (SecurityException e) {
                Log.e(TAG, "Missing BLUETOOTH_CONNECT permission", e);
            }
        }
        return list;
    }

    @SuppressLint("MissingPermission")
    public void connect(BluetoothDevice device) {
        if (status == ConnectionStatus.CONNECTING || status == ConnectionStatus.CONNECTED) return;

        setStatus(ConnectionStatus.CONNECTING);
        Log.d(TAG, "Connecting to " + device.getAddress() + " ...");

        new Thread(() -> {
            try {
                try { bluetoothAdapter.cancelDiscovery(); } catch (Exception ignored) {}

                socket = device.createRfcommSocketToServiceRecord(SPP_UUID);
                socket.connect();

                outStream = socket.getOutputStream();

                // Start the continuous read thread
                readThread = new ReadThread(socket.getInputStream());
                readThread.start();

                setStatus(ConnectionStatus.CONNECTED);
                Log.d(TAG, "✓ Connected to " + device.getAddress());

            } catch (IOException | SecurityException e) {
                Log.e(TAG, "✗ Connection failed: " + e.getMessage());
                closeSocket();
                setStatus(ConnectionStatus.DISCONNECTED);
            }
        }, "BT-Connect").start();
    }

    public void disconnect() {
        Log.d(TAG, "disconnect() called");
        stopReadThread();
        closeSocket();
        setStatus(ConnectionStatus.DISCONNECTED);
    }

    /** Send a command string to HC-05 (e.g. "CMD=MOTION,DIR=FWD\n"). */
    public boolean sendCommand(String cmd) {
        if (outStream != null && status == ConnectionStatus.CONNECTED) {
            try {
                String finalCmd = cmd.endsWith("\n") ? cmd : cmd + "\n";
                outStream.write(finalCmd.getBytes());
                Log.d(TAG, "Sent command: " + finalCmd.replace("\n", "\\n"));
                return true;
            } catch (IOException e) {
                Log.e(TAG, "Write error: " + e.getMessage());
                return false;
            }
        }
        return false;
    }

    // ── Internal ───────────────────────────────────────────────────────
    private void setStatus(ConnectionStatus s) {
        boolean changed = (this.status != s);
        this.status = s;
        
        if (changed) {
            playSoundForStatus(s);
        }

        OnStatusChangedListener l = statusListener;
        if (l != null) {
            mainHandler.post(() -> l.onStatusChanged(s));
        }
    }

    private void playSoundForStatus(ConnectionStatus s) {
        try {
            android.media.ToneGenerator toneGen = new android.media.ToneGenerator(android.media.AudioManager.STREAM_NOTIFICATION, 100);
            if (s == ConnectionStatus.CONNECTED) {
                // TONE_PROP_ACK is an ascending/positive beep
                toneGen.startTone(android.media.ToneGenerator.TONE_PROP_ACK, 200);
            } else if (s == ConnectionStatus.DISCONNECTED) {
                // TONE_PROP_NACK is a descending/negative beep
                toneGen.startTone(android.media.ToneGenerator.TONE_PROP_NACK, 300);
            } else {
                toneGen.release();
                return;
            }
            // Release the ToneGenerator after the sound finishes
            mainHandler.postDelayed(toneGen::release, 500);
        } catch (Exception e) {
            Log.e(TAG, "Error playing sound: " + e.getMessage());
        }
    }

    private void closeSocket() {
        try { if (outStream != null) outStream.close(); } catch (IOException ignored) {}
        try { if (socket != null) socket.close(); } catch (IOException ignored) {}
        outStream = null;
        socket = null;
    }

    private void stopReadThread() {
        if (readThread != null) {
            readThread.cancel();
            readThread = null;
        }
    }

    // ── Background read thread ─────────────────────────────────────────
    private class ReadThread extends Thread {
        private final InputStream in;
        private volatile boolean running = true;

        ReadThread(InputStream inputStream) {
            this.in = inputStream;
            setName("BT-Read");
            setDaemon(true);
        }

        @Override
        public void run() {
            Log.d(TAG, "ReadThread started");
            byte[] buf = new byte[1024];
            StringBuilder sb = new StringBuilder();

            while (running) {
                try {
                    int len = in.read(buf);
                    if (len == -1) {
                        Log.d(TAG, "InputStream returned -1 (EOF)");
                        break;
                    }

                    sb.append(new String(buf, 0, len));

                    // Extract every complete line
                    int idx;
                    while ((idx = sb.indexOf("\n")) != -1) {
                        String line = sb.substring(0, idx).replace("\r", "").trim();
                        sb.delete(0, idx + 1);

                        if (!line.isEmpty()) {
                            Log.d(TAG, "RX: " + line);
                            OnMessageReceivedListener l = messageListener;
                            if (l != null) {
                                final String packet = line;
                                mainHandler.post(() -> l.onMessageReceived(packet));
                            }
                        }
                    }
                } catch (IOException e) {
                    if (running) {
                        Log.e(TAG, "Read error (connection lost): " + e.getMessage());
                        setStatus(ConnectionStatus.DISCONNECTED);
                    }
                    break;
                }
            }
            Log.d(TAG, "ReadThread stopped");
        }

        void cancel() {
            running = false;
            try { in.close(); } catch (IOException ignored) {}
        }
    }
}
