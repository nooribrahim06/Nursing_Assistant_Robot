package com.robot.patientmonitor.activities;

import android.os.Bundle;
import android.util.Log;
import android.widget.EditText;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.robot.patientmonitor.R;
import com.robot.patientmonitor.data.FirebaseRepository;
import com.robot.patientmonitor.models.Patient;

public class AddPatientActivity extends AppCompatActivity {

    private static final String TAG = "ADD_PATIENT";
    private EditText etId, etName, etAge, etRoom, etNotes;
    private FirebaseRepository repository;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_add_patient);

        repository = new FirebaseRepository();

        etId    = findViewById(R.id.etPatientId);
        etName  = findViewById(R.id.etName);
        etAge   = findViewById(R.id.etAge);
        etRoom  = findViewById(R.id.etRoom);
        etNotes = findViewById(R.id.etNotes);

        findViewById(R.id.btnSave).setOnClickListener(v -> savePatient());
        findViewById(R.id.btnCancel).setOnClickListener(v -> finish());

        if (getIntent().hasExtra("patientId")) {
            android.widget.TextView tvTitle = findViewById(R.id.tvTitle);
            if (tvTitle != null) tvTitle.setText("Edit Patient");
            
            etId.setText(getIntent().getStringExtra("patientId"));
            etId.setEnabled(false);
            etName.setText(getIntent().getStringExtra("name"));
            etAge.setText(getIntent().getStringExtra("age"));
            etRoom.setText(getIntent().getStringExtra("room"));
            etNotes.setText(getIntent().getStringExtra("notes"));
        }
    }

    private void savePatient() {
        String id    = etId.getText().toString().trim();
        String name  = etName.getText().toString().trim();
        String age   = etAge.getText().toString().trim();
        String room  = etRoom.getText().toString().trim();
        String notes = etNotes.getText().toString().trim();

        if (id.isEmpty()) {
            etId.setError("Patient ID is required");
            return;
        }
        if (name.isEmpty()) {
            etName.setError("Name is required");
            return;
        }

        Patient p = new Patient(id, name, age, room, notes);
        Log.d(TAG, "Saving patient: " + id + " / " + name);

        // Disable button to prevent double-tap
        findViewById(R.id.btnSave).setEnabled(false);

        repository.addPatient(p, new FirebaseRepository.OnCompleteCallback() {
            @Override
            public void onSuccess() {
                Log.d(TAG, "Patient saved successfully");
                Toast.makeText(AddPatientActivity.this, "Patient saved ✓", Toast.LENGTH_SHORT).show();
                finish(); // only finish AFTER write is confirmed
            }

            @Override
            public void onError(String message) {
                Log.e(TAG, "Save failed: " + message);
                Toast.makeText(AddPatientActivity.this, "Save failed: " + message, Toast.LENGTH_LONG).show();
                findViewById(R.id.btnSave).setEnabled(true);
            }
        });
    }
}
