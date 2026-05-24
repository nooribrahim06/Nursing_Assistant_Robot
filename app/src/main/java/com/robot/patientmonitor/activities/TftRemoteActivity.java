package com.robot.patientmonitor.activities;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.robot.patientmonitor.R;
import com.robot.patientmonitor.bluetooth.BluetoothManager;

/**
 * TFT Remote — sends UI key commands to the STM32 TFT screen
 * through the existing HC-05 Bluetooth connection.
 *
 * Three panels:
 *   1. Main  — 6 robot mode buttons matching TFT menu order
 *   2. Medicine — numeric keypad for timer/dose input
 *   3. Vision — D-pad for camera/vision navigation
 *
 * This screen is send-only: it does NOT bind a message listener.
 * It only binds a status listener to show connection state.
 *
 * Vision D-pad uses dedicated arrow commands:
 *   CMD=UI,KEY=UP / DOWN / LEFT / RIGHT
 */
public class TftRemoteActivity extends AppCompatActivity {

    private static final String TAG = "TFT_REMOTE";

    private BluetoothManager btManager;
    private TextView tvConnectionStatus, tvLastCommand, tvTitle;
    private View statusDot;

    // Panels
    private LinearLayout panelMain, panelMedicine, panelVision, panelMore;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_tft_remote);

        btManager = BluetoothManager.getInstance();

        tvTitle            = findViewById(R.id.tvTitle);
        tvConnectionStatus = findViewById(R.id.tvConnectionStatus);
        statusDot          = findViewById(R.id.statusDot);
        tvLastCommand      = findViewById(R.id.tvLastCommand);

        panelMain     = findViewById(R.id.panelMain);
        panelMedicine = findViewById(R.id.panelMedicine);
        panelVision   = findViewById(R.id.panelVision);
        panelMore     = findViewById(R.id.panelMore);

        if (btManager.getStatus() != BluetoothManager.ConnectionStatus.CONNECTED) {
            Toast.makeText(this, "Bluetooth not connected", Toast.LENGTH_LONG).show();
        }

        setupMainPanel();
        setupMorePanel();
        setupMedicinePanel();
        setupVisionPanel();
    }

    // ── Panel switching ────────────────────────────────────────────────
    private void showPanel(String which) {
        panelMain.setVisibility(View.GONE);
        panelMedicine.setVisibility(View.GONE);
        panelVision.setVisibility(View.GONE);
        panelMore.setVisibility(View.GONE);

        switch (which) {
            case "medicine":
                panelMedicine.setVisibility(View.VISIBLE);
                tvTitle.setText("TFT Remote — Medicine");
                break;
            case "vision":
                panelVision.setVisibility(View.VISIBLE);
                tvTitle.setText("TFT Remote — Vision");
                break;
            case "more":
                panelMore.setVisibility(View.VISIBLE);
                tvTitle.setText("TFT Remote — More Menu");
                break;
            default:
                panelMain.setVisibility(View.VISIBLE);
                tvTitle.setText("TFT Remote");
                break;
        }
    }

    // ── Main panel setup ───────────────────────────────────────────────
    private void setupMainPanel() {
        // 6 robot modes — same order as TFT main menu
        findViewById(R.id.btnMode1).setOnClickListener(v -> sendKey("1")); // Sanitizing
        findViewById(R.id.btnMode2).setOnClickListener(v -> sendKey("2")); // Heart Rate
        findViewById(R.id.btnMode3).setOnClickListener(v -> sendKey("3")); // Breathing
        findViewById(R.id.btnMode5).setOnClickListener(v -> sendKey("5")); // Temperature

        // Mode 4 — Medicine: send command AND open medicine input panel
        findViewById(R.id.btnMode4).setOnClickListener(v -> {
            sendKey("4");
            showPanel("medicine");
        });

        // Mode 0 — More Menu: send command AND open more menu panel
        findViewById(R.id.btnMode0).setOnClickListener(v -> {
            sendKey("0");
            showPanel("more");
        });

        // Quick actions
        findViewById(R.id.btnMotionControl).setOnClickListener(v ->
                startActivity(new Intent(this, MotionControlActivity.class)));

        findViewById(R.id.btnSmokeOff).setOnClickListener(v ->
                sendRaw("CMD=SMOKE,ALERT=OFF"));

        findViewById(R.id.btnMedOff).setOnClickListener(v ->
                sendRaw("CMD=MED,ALERT=OFF"));

        findViewById(R.id.btnExitD).setOnClickListener(v -> sendKey("D"));
    }

    // ── More panel setup ───────────────────────────────────────────────
    private void setupMorePanel() {
        // Mode 6 — Vision: send command AND open vision control panel
        findViewById(R.id.btnMore6).setOnClickListener(v -> {
            sendKey("6");
            showPanel("vision");
        });

        // Mode 7 — Vein Finder
        findViewById(R.id.btnMore7).setOnClickListener(v -> sendKey("7"));

        // Mode 8 — Stress Test
        findViewById(R.id.btnMore8).setOnClickListener(v -> sendKey("8"));

        // C Back — sends command AND returns to main panel
        findViewById(R.id.btnMoreC).setOnClickListener(v -> {
            sendKey("C");
            showPanel("main");
        });

        // D Exit View — sends command for vein/stress
        findViewById(R.id.btnMoreD).setOnClickListener(v -> sendKey("D"));
    }

    // ── Medicine panel setup ───────────────────────────────────────────
    private void setupMedicinePanel() {
        // Digit keys 0–9
        findViewById(R.id.btnMedKey0).setOnClickListener(v -> sendKey("0"));
        findViewById(R.id.btnMedKey1).setOnClickListener(v -> sendKey("1"));
        findViewById(R.id.btnMedKey2).setOnClickListener(v -> sendKey("2"));
        findViewById(R.id.btnMedKey3).setOnClickListener(v -> sendKey("3"));
        findViewById(R.id.btnMedKey4).setOnClickListener(v -> sendKey("4"));
        findViewById(R.id.btnMedKey5).setOnClickListener(v -> sendKey("5"));
        findViewById(R.id.btnMedKey6).setOnClickListener(v -> sendKey("6"));
        findViewById(R.id.btnMedKey7).setOnClickListener(v -> sendKey("7"));
        findViewById(R.id.btnMedKey8).setOnClickListener(v -> sendKey("8"));
        findViewById(R.id.btnMedKey9).setOnClickListener(v -> sendKey("9"));

        // Control keys
        findViewById(R.id.btnMedA).setOnClickListener(v -> sendKey("A")); // OK / Confirm
        findViewById(R.id.btnMedB).setOnClickListener(v -> sendKey("B")); // Clear

        // C Back — sends command AND returns to main panel
        findViewById(R.id.btnMedC).setOnClickListener(v -> {
            sendKey("C");
            showPanel("main");
        });

        // Back to modes — UI only, no BT command
        findViewById(R.id.btnMedBackToModes).setOnClickListener(v -> showPanel("main"));
    }

    // ── Vision panel setup ─────────────────────────────────────────────
    private void setupVisionPanel() {
        // D-pad — dedicated arrow commands (prefixed to avoid overlap with motion)
        findViewById(R.id.btnVisUp).setOnClickListener(v -> sendKey("CAM_UP"));
        findViewById(R.id.btnVisDown).setOnClickListener(v -> sendKey("CAM_DOWN"));
        findViewById(R.id.btnVisLeft).setOnClickListener(v -> sendKey("CAM_LEFT"));
        findViewById(R.id.btnVisRight).setOnClickListener(v -> sendKey("CAM_RIGHT"));
        findViewById(R.id.btnVisOk).setOnClickListener(v -> sendKey("A")); // OK / Select

        // C Back — sends command AND returns to main panel
        findViewById(R.id.btnVisBack).setOnClickListener(v -> {
            sendKey("C");
            showPanel("main");
        });

        // D Exit — sends command AND returns to main panel
        findViewById(R.id.btnVisExit).setOnClickListener(v -> {
            sendKey("0");
            showPanel("main");
        });

        // Back to modes — UI only, no BT command
        findViewById(R.id.btnVisBackToModes).setOnClickListener(v -> showPanel("main"));
    }

    // ── Send helpers ───────────────────────────────────────────────────

    /** Sends CMD=UI,KEY=X where X is the key value (e.g. "1", "A", "UP"). */
    private void sendKey(String key) {
        sendRaw("CMD=UI,KEY=" + key);
    }

    /** Sends any raw command string through BluetoothManager. */
    private void sendRaw(String cmd) {
        if (!cmd.endsWith("\n")) {
            cmd += "\n";
        }
        
        if (btManager.getStatus() != BluetoothManager.ConnectionStatus.CONNECTED) {
            Toast.makeText(this, "Bluetooth not connected", Toast.LENGTH_SHORT).show();
            Log.w(TAG, "Cannot send — BT disconnected: " + cmd);
            tvLastCommand.setText("FAILED (disconnected): " + cmd);
            return;
        }

        boolean sent = btManager.sendCommand(cmd);
        if (sent) {
            Log.d(TAG, "Sent OK: " + cmd);
            tvLastCommand.setText("Last command: " + cmd);
        } else {
            Log.e(TAG, "Send FAILED: " + cmd);
            Toast.makeText(this, "Send failed: " + cmd, Toast.LENGTH_SHORT).show();
            tvLastCommand.setText("FAILED: " + cmd);
        }
    }

    // ── Lifecycle — status listener only (no message listener) ─────────
    @Override
    protected void onResume() {
        super.onResume();
        updateStatus(btManager.getStatus());
        btManager.setStatusListener(this::updateStatus);
    }

    @Override
    protected void onPause() {
        super.onPause();
        btManager.clearListeners();
    }

    private void updateStatus(BluetoothManager.ConnectionStatus s) {
        tvConnectionStatus.setText(s.name());
        int color;
        switch (s) {
            case CONNECTED:  color = getResources().getColor(R.color.status_connected);    break;
            case CONNECTING: color = getResources().getColor(R.color.status_connecting);    break;
            default:         color = getResources().getColor(R.color.status_disconnected);
        }
        tvConnectionStatus.setTextColor(color);
        if (statusDot != null) statusDot.setBackgroundColor(color);
    }
}
