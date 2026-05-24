package com.robot.patientmonitor.activities;

import android.os.Bundle;
import android.util.Log;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.robot.patientmonitor.R;
import com.robot.patientmonitor.bluetooth.BluetoothManager;

public class MotionControlActivity extends AppCompatActivity {

    private static final String TAG = "MOTION_CTRL";

    private BluetoothManager btManager;
    private Button btnForward, btnBackward, btnLeft, btnRight, btnStop, btnEnterPhone;
    private TextView tvMode, tvLastCommand;
    private boolean phoneControlActive = false;
    private boolean isExiting = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_motion_control);

        btManager = BluetoothManager.getInstance();

        btnForward = findViewById(R.id.btnForward);
        btnBackward = findViewById(R.id.btnBackward);
        btnLeft = findViewById(R.id.btnLeft);
        btnRight = findViewById(R.id.btnRight);
        btnStop = findViewById(R.id.btnStop);
        btnEnterPhone = findViewById(R.id.btnEnterPhone);
        tvMode = findViewById(R.id.tvMode);
        tvLastCommand = findViewById(R.id.tvLastCommand);

        setDirectionButtonsEnabled(false);
        tvMode.setText("LINE TRACKING MODE");
        tvMode.setTextColor(getResources().getColor(R.color.status_disconnected));
        tvLastCommand.setText("Last command: none");

        if (btManager.getStatus() != BluetoothManager.ConnectionStatus.CONNECTED) {
            Toast.makeText(this, "Bluetooth not connected", Toast.LENGTH_LONG).show();
        }

        btnEnterPhone.setOnClickListener(v -> {
            if (sendCommand("CMD=MOTION,MODE=PHONE\n")) {
                phoneControlActive = true;
                setDirectionButtonsEnabled(true);
                tvMode.setText("PHONE CONTROL");
                tvMode.setTextColor(getResources().getColor(R.color.status_connected));
            }
        });

        btnForward.setOnClickListener(v -> sendCommand("CMD=MOTION,DIR=FWD\n"));
        btnBackward.setOnClickListener(v -> sendCommand("CMD=MOTION,DIR=BACK\n"));
        btnLeft.setOnClickListener(v -> sendCommand("CMD=MOTION,DIR=LEFT\n"));
        btnRight.setOnClickListener(v -> sendCommand("CMD=MOTION,DIR=RIGHT\n"));
        btnStop.setOnClickListener(v -> sendCommand("CMD=MOTION,DIR=STOP\n"));
    }

    private void setDirectionButtonsEnabled(boolean enabled) {
        btnForward.setEnabled(enabled);
        btnBackward.setEnabled(enabled);
        btnLeft.setEnabled(enabled);
        btnRight.setEnabled(enabled);
    }

    private boolean sendCommand(String cmd) {
        if (btManager.getStatus() != BluetoothManager.ConnectionStatus.CONNECTED) {
            Toast.makeText(this, "Bluetooth not connected", Toast.LENGTH_SHORT).show();
            Log.w(TAG, "Cannot send — BT disconnected: " + cmd.replace("\n", "\\n"));
            return false;
        }
        boolean sent = btManager.sendCommand(cmd);
        String displayCmd = cmd.replace("\n", "");
        if (sent) {
            Log.d(TAG, "Sent OK: " + cmd.replace("\n", "\\n"));
            Toast.makeText(this, "Sent: " + displayCmd, Toast.LENGTH_SHORT).show();
            tvLastCommand.setText("Last command: " + displayCmd);
        } else {
            Log.e(TAG, "Send FAILED: " + cmd.replace("\n", "\\n"));
            Toast.makeText(this, "Send failed: " + displayCmd, Toast.LENGTH_SHORT).show();
            tvLastCommand.setText("FAILED: " + displayCmd);
        }
        return sent;
    }

    private void exitPhoneControl() {
        if (isExiting) return;
        isExiting = true;
        if (btManager.getStatus() == BluetoothManager.ConnectionStatus.CONNECTED) {
            btManager.sendCommand("CMD=MOTION,DIR=STOP\n");
            Log.d(TAG, "Exit → Sent: CMD=MOTION,DIR=STOP\\n");
            btManager.sendCommand("CMD=MOTION,MODE=LINE\n");
            Log.d(TAG, "Exit → Sent: CMD=MOTION,MODE=LINE\\n");
        } else {
            Log.w(TAG, "Exit — BT disconnected, skipping STOP/LINE commands");
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        isExiting = false;
        btManager.setStatusListener(status -> {
            if (status != BluetoothManager.ConnectionStatus.CONNECTED) {
                phoneControlActive = false;
                setDirectionButtonsEnabled(false);
                tvMode.setText("DISCONNECTED");
                tvMode.setTextColor(getResources().getColor(R.color.status_disconnected));
                Toast.makeText(MotionControlActivity.this, "Bluetooth not connected", Toast.LENGTH_SHORT).show();
            }
        });
    }

    @Override
    protected void onPause() {
        super.onPause();
        btManager.clearListeners();
    }

    @Override
    protected void onDestroy() {
        exitPhoneControl();
        super.onDestroy();
    }

    @Override
    public void onBackPressed() {
        exitPhoneControl();
        super.onBackPressed();
    }
}
