package com.robot.patientmonitor.activities;

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
import com.robot.patientmonitor.models.Reading;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class HistoryActivity extends AppCompatActivity {

    private static final String TAG = "HISTORY";

    private RecyclerView rvHistory;
    private TextView tvEmpty;
    private ReadingAdapter adapter;
    private final List<Reading> readings = new ArrayList<>();
    private FirebaseRepository repository;
    private Patient selectedPatient;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_history);

        repository = new FirebaseRepository();
        selectedPatient = AppState.getInstance().getSelectedPatient();

        if (selectedPatient == null) {
            Toast.makeText(this, "No patient selected", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        ((TextView) findViewById(R.id.tvHistoryTitle))
                .setText("📋 History — " + selectedPatient.name);

        tvEmpty   = findViewById(R.id.tvEmpty);
        rvHistory = findViewById(R.id.rvHistory);
        rvHistory.setLayoutManager(new LinearLayoutManager(this));
        adapter = new ReadingAdapter();
        rvHistory.setAdapter(adapter);

        loadHistory();
    }

    private void loadHistory() {
        repository.loadSavedReadings(selectedPatient.patientId,
                new FirebaseRepository.OnReadingsLoaded() {
                    @Override
                    public void onLoaded(List<Reading> list) {
                        readings.clear();
                        readings.addAll(list);
                        // newest first
                        Collections.sort(readings, (a, b) -> Long.compare(b.timestamp, a.timestamp));
                        adapter.notifyDataSetChanged();
                        tvEmpty.setVisibility(readings.isEmpty() ? View.VISIBLE : View.GONE);
                        Log.d(TAG, "Loaded " + readings.size() + " readings");
                    }

                    @Override
                    public void onError(String message) {
                        Toast.makeText(HistoryActivity.this, "Error: " + message, Toast.LENGTH_SHORT).show();
                    }
                });
    }

    // ── Adapter ────────────────────────────────────────────────────────
    private class ReadingAdapter extends RecyclerView.Adapter<ReadingAdapter.VH> {
        private final SimpleDateFormat sdf =
                new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());

        @NonNull @Override
        public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View v = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_reading, parent, false);
            return new VH(v);
        }

        @Override
        public void onBindViewHolder(@NonNull VH h, int pos) {
            Reading r = readings.get(pos);
            h.tvTime.setText(sdf.format(new Date(r.timestamp)));
            h.tvBpm.setText("BPM: " + r.bpm);
            h.tvSpo2.setText("SpO2: " + r.spo2 + "%");
            h.tvBreath.setText("Breath: " + Reading.getBreathDescription(r.breath));
            h.tvSmoke.setText("Smoke: " + r.smoke);
            h.tvMed.setText("MED: " + r.med);
            h.tvAlert.setText("Alert: " + r.alert);
        }

        @Override public int getItemCount() { return readings.size(); }

        class VH extends RecyclerView.ViewHolder {
            TextView tvTime, tvBpm, tvSpo2, tvBreath, tvSmoke, tvMed, tvAlert;
            VH(View v) {
                super(v);
                tvTime   = v.findViewById(R.id.tvTimestamp);
                tvBpm    = v.findViewById(R.id.tvBpm);
                tvSpo2   = v.findViewById(R.id.tvSpo2);
                tvBreath = v.findViewById(R.id.tvBreath);
                tvSmoke  = v.findViewById(R.id.tvSmoke);
                tvMed    = v.findViewById(R.id.tvMed);
                tvAlert  = v.findViewById(R.id.tvAlert);
            }
        }
    }
}
