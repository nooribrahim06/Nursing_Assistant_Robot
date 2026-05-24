package com.robot.patientmonitor.activities;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.robot.patientmonitor.R;
import com.robot.patientmonitor.bluetooth.BluetoothManager;
import com.robot.patientmonitor.data.AppState;
import com.robot.patientmonitor.data.FirebaseRepository;
import com.robot.patientmonitor.models.Patient;
import com.robot.patientmonitor.models.Reading;
import com.robot.patientmonitor.parser.PacketParser;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class DashboardActivity extends AppCompatActivity {

    private static final String TAG = "DASHBOARD";

    private TextView tvPatientName, tvPatientId;
    private TextView tvStatus, tvLastUpdated;
    private TextView tvBpm, tvSpo2, tvBreath, tvSmoke, tvSmokeRaw, tvMed, tvAlert, tvRaw;
    private View statusDot;

    private BluetoothManager btManager;
    private FirebaseRepository repository;
    private Patient selectedPatient;
    private Reading currentReading;

    private TextView tvHealthStatus, tvHealthReason;
    private View llMedicineAlert;
    private TextView tvMedicineAlertText;
    private Button btnDismissMedAlert;
    private View llSmokeAlert;
    private TextView tvSmokeAlertText;
    private Button btnDismissSmokeAlert;
    private List<com.robot.patientmonitor.models.Medicine> activeMedicines = new ArrayList<>();

    private final SimpleDateFormat timeFmt =
            new SimpleDateFormat("HH:mm:ss", Locale.getDefault());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_dashboard);

        btManager  = BluetoothManager.getInstance();
        repository = new FirebaseRepository();

        initViews();

        // Buttons
        findViewById(R.id.btnSave).setOnClickListener(v -> saveReading());
        findViewById(R.id.btnHistory).setOnClickListener(v ->
                startActivity(new Intent(this, HistoryActivity.class)));
        findViewById(R.id.btnMedicines).setOnClickListener(v ->
                startActivity(new Intent(this, MedicinesActivity.class)));
        findViewById(R.id.btnBluetooth).setOnClickListener(v ->
                startActivity(new Intent(this, BluetoothConnectActivity.class)));
        findViewById(R.id.btnBackPatients).setOnClickListener(v -> finish());

        // Resolve patient — try AppState first, then Intent extra, then Firebase
        resolvePatient();
    }

    private void resolvePatient() {
        // 1. Try AppState
        selectedPatient = AppState.getInstance().getSelectedPatient();
        if (selectedPatient != null) {
            Log.d(TAG, "Patient from AppState: " + selectedPatient.patientId);
            showPatientInfo();
            loadActiveMedicines();
            return;
        }

        // 2. Try Intent extra
        String intentId = getIntent().getStringExtra("patientId");
        if (intentId != null && !intentId.isEmpty()) {
            Log.d(TAG, "Loading patient from Firebase by Intent extra: " + intentId);
            repository.loadPatientById(intentId, new FirebaseRepository.OnPatientLoaded() {
                @Override
                public void onLoaded(Patient patient) {
                    selectedPatient = patient;
                    AppState.getInstance().setSelectedPatient(patient);
                    Log.d(TAG, "Patient loaded from Firebase: " + patient.patientId);
                    showPatientInfo();
                    loadActiveMedicines();
                }

                @Override
                public void onError(String message) {
                    Log.e(TAG, "Could not load patient: " + message);
                    Toast.makeText(DashboardActivity.this, "Patient not found", Toast.LENGTH_SHORT).show();
                }
            });
            return;
        }

        // 3. No patient at all
        Log.e(TAG, "No patient selected — showing error");
        tvPatientName.setText("No patient selected");
        tvPatientId.setText("Go back and select a patient");
    }

    private void loadActiveMedicines() {
        if (selectedPatient == null) return;
        repository.loadMedicines(selectedPatient.patientId, new FirebaseRepository.OnMedicinesLoaded() {
            @Override
            public void onLoaded(List<com.robot.patientmonitor.models.Medicine> medicines) {
                activeMedicines.clear();
                for (com.robot.patientmonitor.models.Medicine m : medicines) {
                    if (m.active) activeMedicines.add(m);
                }
            }
            @Override
            public void onError(String msg) {
                Log.e(TAG, "Error loading medicines: " + msg);
            }
        });
    }

    private void initViews() {
        tvPatientName = findViewById(R.id.tvPatientName);
        tvPatientId   = findViewById(R.id.tvPatientId);
        tvStatus      = findViewById(R.id.tvConnectionStatus);
        tvLastUpdated = findViewById(R.id.tvLastUpdated);
        statusDot     = findViewById(R.id.statusDot);
        tvBpm   = findViewById(R.id.tvBpm);
        tvSpo2  = findViewById(R.id.tvSpo2);
        tvBreath = findViewById(R.id.tvBreath);
        tvSmoke = findViewById(R.id.tvSmoke);
        tvSmokeRaw = findViewById(R.id.tvSmokeRaw);
        tvMed   = findViewById(R.id.tvMed);
        tvAlert = findViewById(R.id.tvAlert);
        tvRaw   = findViewById(R.id.tvRawPacket);

        tvHealthStatus = findViewById(R.id.tvHealthStatus);
        tvHealthReason = findViewById(R.id.tvHealthReason);
        llMedicineAlert = findViewById(R.id.llMedicineAlert);
        tvMedicineAlertText = findViewById(R.id.tvMedicineAlertText);
        btnDismissMedAlert = findViewById(R.id.btnDismissMedAlert);
        btnDismissMedAlert.setOnClickListener(v -> dismissMedicineAlert());

        llSmokeAlert = findViewById(R.id.llSmokeAlert);
        tvSmokeAlertText = findViewById(R.id.tvSmokeAlertText);
        btnDismissSmokeAlert = findViewById(R.id.btnDismissSmokeAlert);
        btnDismissSmokeAlert.setOnClickListener(v -> dismissSmokeAlert());
    }

    private void showPatientInfo() {
        if (selectedPatient == null) return;
        tvPatientName.setText(selectedPatient.name);
        tvPatientId.setText("ID: " + selectedPatient.patientId);
    }

    // ── Bluetooth callbacks ────────────────────────────────────────────
    private void onStatusChanged(BluetoothManager.ConnectionStatus s) {
        tvStatus.setText(s.name());
        int color;
        switch (s) {
            case CONNECTED:  color = getResources().getColor(R.color.status_connected); break;
            case CONNECTING: color = getResources().getColor(R.color.status_connecting); break;
            default:         color = getResources().getColor(R.color.status_disconnected);
        }
        tvStatus.setTextColor(color);
        statusDot.setBackgroundColor(color);
    }

    private void onPacket(String raw) {
        tvRaw.setText("Raw: " + raw);
        Log.d(TAG, "RX: " + raw);

        if (selectedPatient == null) {
            Log.d(TAG, "No patient selected — skipping parse");
            return;
        }

        Reading r = PacketParser.parse(raw, selectedPatient.patientId);
        if (r == null) {
            Log.d(TAG, "Parse returned null (not VITALS or corrupt)");
            return;
        }

        Log.d(TAG, "Parsed → BPM=" + r.bpm + " SPO2=" + r.spo2 +
                " BREATH=" + r.breath + " SMOKE=" + r.smoke +
                " MED=" + r.med + " ALERT=" + r.alert);

        currentReading = r;
        AppState.getInstance().setLatestReading(r);

        tvBpm.setText(String.valueOf(r.bpm));
        tvSpo2.setText(r.spo2 + "%");
        tvBreath.setText(Reading.getBreathDescription(r.breath));
        
        if (r.smoke < 2000) {
            tvSmoke.setText("SAFE");
            tvSmoke.setTextColor(android.graphics.Color.parseColor("#81C784"));
        } else if (r.smoke < 3000) {
            tvSmoke.setText("WARNING");
            tvSmoke.setTextColor(android.graphics.Color.parseColor("#FFB74D"));
        } else {
            tvSmoke.setText("DANGER");
            tvSmoke.setTextColor(android.graphics.Color.parseColor("#CF6679"));
        }
        if (tvSmokeRaw != null) {
            tvSmokeRaw.setText("Raw: " + r.smoke);
        }

        tvMed.setText(String.valueOf(r.med));
        tvAlert.setText(r.alert);
        tvLastUpdated.setText(timeFmt.format(new Date()));

        updateHealthOverview(r);
        updateMedicineAlert(r);
        updateSmokeAlert(r);

        repository.updateLatest(selectedPatient.patientId, r, null);
    }

    private void updateHealthOverview(Reading r) {
        if (r == null) {
            tvHealthStatus.setText("No Data");
            tvHealthStatus.setTextColor(getResources().getColor(R.color.text_hint));
            tvHealthReason.setText("Waiting for vitals");
            return;
        }

        String status;
        String reason;
        int color;

        if (r.alert != null && !r.alert.equals("NONE")) {
            status = "Critical Alert";
            reason = "Active alert: " + r.alert;
            color = android.graphics.Color.parseColor("#CF6679"); // dark theme red
        } else if (r.spo2 > 0 && r.spo2 < 92) {
            status = "Critical Alert";
            reason = "SpO2 critically low";
            color = android.graphics.Color.parseColor("#CF6679");
        } else if (r.smoke >= 3000) {
            status = "Critical Alert";
            reason = "Smoke level dangerous";
            color = android.graphics.Color.parseColor("#CF6679");
        } else if (r.spo2 > 0 && r.spo2 < 95) {
            status = "Needs Attention";
            reason = "SpO2 below normal threshold";
            color = android.graphics.Color.parseColor("#FFB74D"); // dark theme orange
        } else if (r.smoke >= 2000 && r.smoke < 3000) {
            status = "Needs Attention";
            reason = "Smoke level elevated";
            color = android.graphics.Color.parseColor("#FFB74D");
        } else if (r.bpm > 0 && (r.bpm < 55 || r.bpm > 110)) {
            status = "Needs Attention";
            reason = "BPM outside normal range";
            color = android.graphics.Color.parseColor("#FFB74D");
        } else {
            status = "Stable";
            reason = "Vitals within selected thresholds";
            color = android.graphics.Color.parseColor("#81C784"); // dark theme green
        }

        tvHealthStatus.setText(status);
        tvHealthStatus.setTextColor(color);
        tvHealthReason.setText(reason);
    }

    private void updateMedicineAlert(Reading r) {
        if (r == null) {
            llMedicineAlert.setVisibility(View.GONE);
            return;
        }

        if (r.alert != null && (r.alert.equals("MED") || r.alert.equals("MEDICINE") || r.alert.equals("MED_ALERT"))) {
            llMedicineAlert.setVisibility(View.VISIBLE);
            if (activeMedicines.isEmpty()) {
                tvMedicineAlertText.setText("No active medicine assigned for this patient.");
            } else {
                StringBuilder sb = new StringBuilder();
                for (com.robot.patientmonitor.models.Medicine m : activeMedicines) {
                    sb.append("- ").append(m.name).append(" ").append(m.dose).append("\n");
                    if (m.notes != null && !m.notes.isEmpty()) {
                        sb.append("  Notes: ").append(m.notes).append("\n");
                    }
                }
                tvMedicineAlertText.setText("Take:\n" + sb.toString().trim());
            }
            btnDismissMedAlert.setEnabled(true);
        } else {
            llMedicineAlert.setVisibility(View.GONE);
        }
    }

    private void dismissMedicineAlert() {
        if (btManager.getStatus() != BluetoothManager.ConnectionStatus.CONNECTED) {
            Toast.makeText(this, "Bluetooth not connected", Toast.LENGTH_SHORT).show();
            return;
        }
        boolean sent = btManager.sendCommand("CMD=MED,ALERT=OFF\n");
        if (sent) {
            llMedicineAlert.setVisibility(View.GONE);
            btnDismissMedAlert.setEnabled(false);
            Toast.makeText(this, "Medicine alert dismissed ✓", Toast.LENGTH_SHORT).show();
            Log.d(TAG, "Dismiss medicine alert command sent");
        } else {
            Toast.makeText(this, "Failed to send dismiss command", Toast.LENGTH_SHORT).show();
        }
    }

    // ── Smoke Alert ────────────────────────────────────────────────────
    private void updateSmokeAlert(Reading r) {
        if (r == null) {
            llSmokeAlert.setVisibility(View.GONE);
            return;
        }

        boolean smokeAlertActive = false;

        // Check alert field from STM32
        if (r.alert != null && (r.alert.equals("SMOKE") || r.alert.equals("SMOKE_ALERT") || r.alert.equals("FIRE"))) {
            smokeAlertActive = true;
        }

        // Check smoke level DANGER threshold
        if (r.smoke >= 3000) {
            smokeAlertActive = true;
        }

        if (smokeAlertActive) {
            llSmokeAlert.setVisibility(View.VISIBLE);
            tvSmokeAlertText.setText("Smoke level dangerous\nEvacuate / check environment\nRaw: " + r.smoke);
            btnDismissSmokeAlert.setEnabled(true);
        } else {
            llSmokeAlert.setVisibility(View.GONE);
        }
    }

    private void dismissSmokeAlert() {
        if (btManager.getStatus() != BluetoothManager.ConnectionStatus.CONNECTED) {
            Toast.makeText(this, "Bluetooth not connected", Toast.LENGTH_SHORT).show();
            return;
        }
        boolean sent = btManager.sendCommand("CMD=SMOKE,ALERT=OFF\n");
        if (sent) {
            llSmokeAlert.setVisibility(View.GONE);
            btnDismissSmokeAlert.setEnabled(false);
            Toast.makeText(this, "Smoke alert dismissed ✓", Toast.LENGTH_SHORT).show();
            Log.d(TAG, "Dismiss smoke alert command sent");
        } else {
            Toast.makeText(this, "Failed to send dismiss command", Toast.LENGTH_SHORT).show();
        }
    }

    // ── Save ───────────────────────────────────────────────────────────
    private void saveReading() {
        if (selectedPatient == null) {
            Toast.makeText(this, "No patient selected", Toast.LENGTH_SHORT).show();
            return;
        }
        if (currentReading == null) {
            Toast.makeText(this, "No reading received yet", Toast.LENGTH_SHORT).show();
            return;
        }
        currentReading.patientId = selectedPatient.patientId;
        currentReading.timestamp = System.currentTimeMillis();

        repository.saveReading(selectedPatient.patientId, currentReading,
                new FirebaseRepository.OnCompleteCallback() {
                    @Override
                    public void onSuccess() {
                        Toast.makeText(DashboardActivity.this, "Reading saved ✓", Toast.LENGTH_SHORT).show();
                    }

                    @Override
                    public void onError(String message) {
                        Toast.makeText(DashboardActivity.this, "Save failed: " + message, Toast.LENGTH_SHORT).show();
                    }
                });
    }

    // ── Lifecycle ──────────────────────────────────────────────────────
    @Override
    protected void onResume() {
        super.onResume();
        Log.d(TAG, "onResume — attaching BT listeners");
        btManager.setMessageListener(this::onPacket);
        btManager.setStatusListener(this::onStatusChanged);
    }

    @Override
    protected void onPause() {
        super.onPause();
        Log.d(TAG, "onPause — clearing BT listeners");
        btManager.clearListeners();
    }
}
