package com.robot.patientmonitor.activities;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.robot.patientmonitor.R;
import com.robot.patientmonitor.data.AppState;
import com.robot.patientmonitor.data.FirebaseRepository;
import com.robot.patientmonitor.models.Medicine;
import com.robot.patientmonitor.models.Patient;
import java.util.ArrayList;
import java.util.List;

public class MedicinesActivity extends AppCompatActivity {

    private FirebaseRepository repository;
    private Patient selectedPatient;
    
    private TextView tvPatientInfo;
    private EditText etName, etDose, etNotes;
    private CheckBox cbActive;
    private RecyclerView rvMedicines;
    
    private List<Medicine> medicinesList = new ArrayList<>();
    private MedicineAdapter adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_medicines);

        repository = new FirebaseRepository();
        selectedPatient = AppState.getInstance().getSelectedPatient();

        if (selectedPatient == null) {
            Toast.makeText(this, "No patient selected", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        tvPatientInfo = findViewById(R.id.tvPatientInfo);
        tvPatientInfo.setText("Patient: " + selectedPatient.name + " (" + selectedPatient.patientId + ")");

        etName = findViewById(R.id.etName);
        etDose = findViewById(R.id.etDose);
        etNotes = findViewById(R.id.etNotes);
        cbActive = findViewById(R.id.cbActive);
        
        rvMedicines = findViewById(R.id.rvMedicines);
        rvMedicines.setLayoutManager(new LinearLayoutManager(this));
        adapter = new MedicineAdapter();
        rvMedicines.setAdapter(adapter);

        findViewById(R.id.btnBack).setOnClickListener(v -> finish());
        
        findViewById(R.id.btnSave).setOnClickListener(v -> saveMedicine());

        loadMedicines();
    }

    private void loadMedicines() {
        repository.loadMedicines(selectedPatient.patientId, new FirebaseRepository.OnMedicinesLoaded() {
            @Override
            public void onLoaded(List<Medicine> medicines) {
                medicinesList.clear();
                medicinesList.addAll(medicines);
                adapter.notifyDataSetChanged();
            }

            @Override
            public void onError(String message) {
                Toast.makeText(MedicinesActivity.this, "Error loading medicines: " + message, Toast.LENGTH_SHORT).show();
            }
        });
    }

    private void saveMedicine() {
        String name = etName.getText().toString().trim();
        String dose = etDose.getText().toString().trim();
        String notes = etNotes.getText().toString().trim();
        boolean active = cbActive.isChecked();

        if (name.isEmpty()) {
            Toast.makeText(this, "Medicine name is required", Toast.LENGTH_SHORT).show();
            return;
        }

        Medicine m = new Medicine(null, name, dose, notes, active, System.currentTimeMillis());
        repository.addMedicine(selectedPatient.patientId, m, new FirebaseRepository.OnCompleteCallback() {
            @Override
            public void onSuccess() {
                Toast.makeText(MedicinesActivity.this, "Medicine added", Toast.LENGTH_SHORT).show();
                etName.setText("");
                etDose.setText("");
                etNotes.setText("");
                cbActive.setChecked(true);
                loadMedicines(); // Refresh list
            }

            @Override
            public void onError(String message) {
                Toast.makeText(MedicinesActivity.this, "Failed to add medicine: " + message, Toast.LENGTH_SHORT).show();
            }
        });
    }

    private class MedicineAdapter extends RecyclerView.Adapter<MedicineAdapter.VH> {

        @NonNull
        @Override
        public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View v = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_medicine, parent, false);
            return new VH(v);
        }

        @Override
        public void onBindViewHolder(@NonNull VH holder, int position) {
            Medicine m = medicinesList.get(position);
            holder.tvMedName.setText(m.name);
            holder.tvMedDose.setText(m.dose.isEmpty() ? "No dose specified" : m.dose);
            holder.tvMedNotes.setText(m.notes.isEmpty() ? "No notes" : m.notes);
            
            // Remove listener to prevent triggering during initial setup
            holder.switchActive.setOnCheckedChangeListener(null);
            holder.switchActive.setChecked(m.active);
            
            holder.switchActive.setOnCheckedChangeListener((buttonView, isChecked) -> {
                repository.updateMedicineActive(selectedPatient.patientId, m.medicineId, isChecked, new FirebaseRepository.OnCompleteCallback() {
                    @Override
                    public void onSuccess() {
                        m.active = isChecked;
                        Toast.makeText(MedicinesActivity.this, "Status updated", Toast.LENGTH_SHORT).show();
                    }

                    @Override
                    public void onError(String message) {
                        // Revert switch on error
                        holder.switchActive.setChecked(!isChecked);
                        Toast.makeText(MedicinesActivity.this, "Update failed: " + message, Toast.LENGTH_SHORT).show();
                    }
                });
            });
        }

        @Override
        public int getItemCount() {
            return medicinesList.size();
        }

        class VH extends RecyclerView.ViewHolder {
            TextView tvMedName, tvMedDose, tvMedNotes;
            Switch switchActive;

            VH(View v) {
                super(v);
                tvMedName = v.findViewById(R.id.tvMedName);
                tvMedDose = v.findViewById(R.id.tvMedDose);
                tvMedNotes = v.findViewById(R.id.tvMedNotes);
                switchActive = v.findViewById(R.id.switchActive);
            }
        }
    }
}
