package com.robot.patientmonitor.activities;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.robot.patientmonitor.R;
import com.robot.patientmonitor.data.AppState;
import com.robot.patientmonitor.data.FirebaseRepository;
import com.robot.patientmonitor.models.Patient;
import java.util.ArrayList;
import java.util.List;

public class PatientListActivity extends AppCompatActivity {

    private static final String TAG = "PATIENT_LIST";

    private RecyclerView rvPatients;
    private TextView tvEmpty;
    private PatientAdapter adapter;
    private final List<Patient> patients = new ArrayList<>();
    private FirebaseRepository repository;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_patient_list);

        repository = new FirebaseRepository();
        rvPatients = findViewById(R.id.rvPatients);
        tvEmpty    = findViewById(R.id.tvEmpty);

        rvPatients.setLayoutManager(new LinearLayoutManager(this));
        adapter = new PatientAdapter();
        rvPatients.setAdapter(adapter);

        findViewById(R.id.btnAddPatient).setOnClickListener(v ->
                startActivity(new Intent(this, AddPatientActivity.class)));

        findViewById(R.id.btnBluetooth).setOnClickListener(v ->
                startActivity(new Intent(this, BluetoothConnectActivity.class)));
    }

    @Override
    protected void onResume() {
        super.onResume();
        Log.d(TAG, "onResume — reloading patients from Firebase");
        loadPatients();
    }

    private void loadPatients() {
        repository.loadPatients(new FirebaseRepository.OnPatientsLoaded() {
            @Override
            public void onLoaded(List<Patient> list) {
                patients.clear();
                patients.addAll(list);
                adapter.notifyDataSetChanged();
                tvEmpty.setVisibility(patients.isEmpty() ? View.VISIBLE : View.GONE);
                rvPatients.setVisibility(patients.isEmpty() ? View.GONE : View.VISIBLE);
                Log.d(TAG, "Displaying " + patients.size() + " patients");
            }

            @Override
            public void onError(String message) {
                Toast.makeText(PatientListActivity.this, "Load error: " + message, Toast.LENGTH_SHORT).show();
                Log.e(TAG, "Load error: " + message);
            }
        });
    }

    // ── Adapter ────────────────────────────────────────────────────────
    private class PatientAdapter extends RecyclerView.Adapter<PatientAdapter.VH> {

        @NonNull @Override
        public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View v = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_patient, parent, false);
            return new VH(v);
        }

        @Override
        public void onBindViewHolder(@NonNull VH h, int pos) {
            Patient p = patients.get(pos);
            h.tvName.setText(p.name != null ? p.name : "—");
            h.tvId.setText("ID: " + (p.patientId != null ? p.patientId : "—"));
            h.tvRoom.setText("Room: " + (p.room != null && !p.room.isEmpty() ? p.room : "—"));

            h.itemView.setOnClickListener(v -> {
                Log.d(TAG, "Selected patient: " + p.patientId + " / " + p.name);
                AppState.getInstance().setSelectedPatient(p);

                Intent intent = new Intent(PatientListActivity.this, DashboardActivity.class);
                intent.putExtra("patientId", p.patientId);
                startActivity(intent);
            });

            h.btnEdit.setOnClickListener(v -> {
                Intent intent = new Intent(PatientListActivity.this, AddPatientActivity.class);
                intent.putExtra("patientId", p.patientId);
                intent.putExtra("name", p.name);
                intent.putExtra("age", p.age);
                intent.putExtra("room", p.room);
                intent.putExtra("notes", p.notes);
                startActivity(intent);
            });

            h.btnDelete.setOnClickListener(v -> {
                new androidx.appcompat.app.AlertDialog.Builder(PatientListActivity.this)
                    .setTitle("Delete Patient")
                    .setMessage("Are you sure you want to delete " + p.name + "?")
                    .setPositiveButton("Delete", (dialog, which) -> {
                        repository.deletePatient(p.patientId, new FirebaseRepository.OnCompleteCallback() {
                            @Override
                            public void onSuccess() {
                                Toast.makeText(PatientListActivity.this, "Patient deleted", Toast.LENGTH_SHORT).show();
                                loadPatients();
                            }
                            @Override
                            public void onError(String message) {
                                Toast.makeText(PatientListActivity.this, "Error: " + message, Toast.LENGTH_SHORT).show();
                            }
                        });
                    })
                    .setNegativeButton("Cancel", null)
                    .show();
            });
        }

        @Override public int getItemCount() { return patients.size(); }

        class VH extends RecyclerView.ViewHolder {
            TextView tvName, tvId, tvRoom;
            View btnEdit, btnDelete;
            VH(View v) {
                super(v);
                tvName = v.findViewById(R.id.tvName);
                tvId   = v.findViewById(R.id.tvId);
                tvRoom = v.findViewById(R.id.tvRoom);
                btnEdit = v.findViewById(R.id.btnEdit);
                btnDelete = v.findViewById(R.id.btnDelete);
            }
        }
    }
}
