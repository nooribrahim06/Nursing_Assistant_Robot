package com.robot.patientmonitor.activities;

import android.Manifest;
import android.bluetooth.BluetoothDevice;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.robot.patientmonitor.R;
import com.robot.patientmonitor.bluetooth.BluetoothManager;
import java.util.List;

/**
 * Connection-only screen. No raw data display.
 * User picks a paired HC-05, connects, then goes back.
 */
public class BluetoothConnectActivity extends AppCompatActivity {

    private static final int REQ_BT = 101;

    private TextView tvStatus;
    private Button btnDisconnect;
    private BluetoothManager btManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_bluetooth_connect);

        btManager     = BluetoothManager.getInstance();
        tvStatus      = findViewById(R.id.tvStatus);
        btnDisconnect = findViewById(R.id.btnDisconnect);

        RecyclerView rv = findViewById(R.id.rvDevices);
        rv.setLayoutManager(new LinearLayoutManager(this));

        btnDisconnect.setOnClickListener(v -> btManager.disconnect());

        checkPermissionsAndLoad(rv);
    }

    // ── Permissions ────────────────────────────────────────────────────
    private void checkPermissionsAndLoad(RecyclerView rv) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ActivityCompat.checkSelfPermission(this,
                    Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                        new String[]{Manifest.permission.BLUETOOTH_CONNECT}, REQ_BT);
                return;
            }
        }
        loadDevices(rv);
    }

    @Override
    public void onRequestPermissionsResult(int req, @NonNull String[] perms, @NonNull int[] res) {
        super.onRequestPermissionsResult(req, perms, res);
        if (req == REQ_BT && res.length > 0 && res[0] == PackageManager.PERMISSION_GRANTED) {
            loadDevices(findViewById(R.id.rvDevices));
        } else {
            Toast.makeText(this, "Bluetooth permission required", Toast.LENGTH_SHORT).show();
        }
    }

    private void loadDevices(RecyclerView rv) {
        List<BluetoothDevice> devices = btManager.getPairedDevices();
        rv.setAdapter(new DeviceAdapter(devices));
    }

    // ── Lifecycle ──────────────────────────────────────────────────────
    @Override
    protected void onResume() {
        super.onResume();
        btManager.setStatusListener(this::updateUI);
    }

    @Override
    protected void onPause() {
        super.onPause();
        // Don't clearListeners here — other activities set their own in onResume
    }

    private void updateUI(BluetoothManager.ConnectionStatus s) {
        tvStatus.setText("Status: " + s.name());
        switch (s) {
            case CONNECTED:
                tvStatus.setTextColor(getResources().getColor(R.color.status_connected));
                btnDisconnect.setVisibility(View.VISIBLE);
                break;
            case CONNECTING:
                tvStatus.setTextColor(getResources().getColor(R.color.status_connecting));
                btnDisconnect.setVisibility(View.GONE);
                break;
            default:
                tvStatus.setTextColor(getResources().getColor(R.color.status_disconnected));
                btnDisconnect.setVisibility(View.GONE);
        }
    }

    // ── Adapter ────────────────────────────────────────────────────────
    private class DeviceAdapter extends RecyclerView.Adapter<DeviceAdapter.VH> {
        private final List<BluetoothDevice> list;
        DeviceAdapter(List<BluetoothDevice> l) { list = l; }

        @NonNull @Override
        public VH onCreateViewHolder(@NonNull ViewGroup p, int vt) {
            View v = LayoutInflater.from(p.getContext())
                    .inflate(android.R.layout.simple_list_item_2, p, false);
            return new VH(v);
        }

        @Override
        public void onBindViewHolder(@NonNull VH h, int pos) {
            BluetoothDevice d = list.get(pos);
            try {
                h.t1.setText(d.getName() != null ? d.getName() : "Unknown");
            } catch (SecurityException e) { h.t1.setText("Unknown"); }
            h.t2.setText(d.getAddress());
            h.itemView.setOnClickListener(v -> btManager.connect(d));
        }

        @Override public int getItemCount() { return list.size(); }

        class VH extends RecyclerView.ViewHolder {
            TextView t1, t2;
            VH(View v) {
                super(v);
                t1 = v.findViewById(android.R.id.text1);
                t2 = v.findViewById(android.R.id.text2);
            }
        }
    }
}
