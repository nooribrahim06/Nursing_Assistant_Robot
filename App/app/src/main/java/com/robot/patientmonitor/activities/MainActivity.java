package com.robot.patientmonitor.activities;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import com.robot.patientmonitor.R;
import com.robot.patientmonitor.bluetooth.BluetoothManager;

public class MainActivity extends AppCompatActivity {

    private TextView tvConnectionStatus;
    private View statusDot;
    private BluetoothManager btManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        btManager = BluetoothManager.getInstance();
        tvConnectionStatus = findViewById(R.id.tvConnectionStatus);
        statusDot = findViewById(R.id.statusDot);

        findViewById(R.id.btnPatients).setOnClickListener(v -> {
            startActivity(new Intent(MainActivity.this, PatientListActivity.class));
        });

        findViewById(R.id.btnBluetooth).setOnClickListener(v -> {
            startActivity(new Intent(MainActivity.this, BluetoothConnectActivity.class));
        });

        findViewById(R.id.btnMotion).setOnClickListener(v -> {
            startActivity(new Intent(MainActivity.this, MotionControlActivity.class));
        });

        findViewById(R.id.btnTftRemote).setOnClickListener(v -> {
            startActivity(new Intent(MainActivity.this, TftRemoteActivity.class));
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateBluetoothStatus(btManager.getStatus());
        btManager.setStatusListener(this::updateBluetoothStatus);
    }

    @Override
    protected void onPause() {
        super.onPause();
        btManager.clearListeners();
    }

    private void updateBluetoothStatus(BluetoothManager.ConnectionStatus s) {
        if (tvConnectionStatus == null) return;
        tvConnectionStatus.setText(s.name());
        int color;
        switch (s) {
            case CONNECTED:  color = getResources().getColor(R.color.status_connected); break;
            case CONNECTING: color = getResources().getColor(R.color.status_connecting); break;
            default:         color = getResources().getColor(R.color.status_disconnected);
        }
        tvConnectionStatus.setTextColor(color);
        if (statusDot != null) statusDot.setBackgroundColor(color);
    }
}
