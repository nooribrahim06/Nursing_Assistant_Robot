package com.robot.patientmonitor.data;

import android.util.Log;
import androidx.annotation.NonNull;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import com.robot.patientmonitor.models.Patient;
import com.robot.patientmonitor.models.Reading;
import java.util.ArrayList;
import java.util.List;

/**
 * Firebase Realtime Database helper.
 *
 * Structure:
 *   patients/{patientId}/profile        → Patient fields
 *   patients/{patientId}/latest         → Reading fields
 *   patients/{patientId}/savedReadings/{autoId} → Reading fields
 */
public class FirebaseRepository {

    private static final String TAG = "FIREBASE";
    private final DatabaseReference db;

    public interface OnCompleteCallback {
        void onSuccess();
        void onError(String message);
    }

    public interface OnPatientsLoaded {
        void onLoaded(List<Patient> patients);
        void onError(String message);
    }

    public interface OnPatientLoaded {
        void onLoaded(Patient patient);
        void onError(String message);
    }

    public interface OnReadingsLoaded {
        void onLoaded(List<Reading> readings);
        void onError(String message);
    }

    public FirebaseRepository() {
        db = FirebaseDatabase.getInstance().getReference();
    }

    // ── Patient CRUD ───────────────────────────────────────────────────

    public void addPatient(Patient p, OnCompleteCallback callback) {
        String path = "patients/" + p.patientId + "/profile";
        Log.d(TAG, "Saving patient to: " + path);

        db.child("patients").child(p.patientId).child("profile")
                .setValue(p.toMap())
                .addOnSuccessListener(unused -> {
                    Log.d(TAG, "Patient saved OK: " + p.patientId);
                    if (callback != null) callback.onSuccess();
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Patient save FAILED: " + e.getMessage());
                    if (callback != null) callback.onError(e.getMessage());
                });
    }

    /** Delete patient from database. */
    public void deletePatient(String patientId, OnCompleteCallback callback) {
        Log.d(TAG, "Deleting patient: " + patientId);
        db.child("patients").child(patientId).removeValue()
                .addOnSuccessListener(unused -> {
                    Log.d(TAG, "Patient deleted OK: " + patientId);
                    if (callback != null) callback.onSuccess();
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Patient delete FAILED: " + e.getMessage());
                    if (callback != null) callback.onError(e.getMessage());
                });
    }

    /** Load all patients (one-shot). */
    public void loadPatients(OnPatientsLoaded callback) {
        Log.d(TAG, "Loading all patients...");
        db.child("patients").addListenerForSingleValueEvent(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                List<Patient> list = new ArrayList<>();
                for (DataSnapshot child : snapshot.getChildren()) {
                    DataSnapshot profileSnap = child.child("profile");
                    Patient p = profileSnap.getValue(Patient.class);
                    if (p != null) {
                        list.add(p);
                        Log.d(TAG, "  Loaded patient: " + p.patientId + " / " + p.name);
                    }
                }
                Log.d(TAG, "Total patients loaded: " + list.size());
                callback.onLoaded(list);
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
                Log.e(TAG, "loadPatients error: " + error.getMessage());
                callback.onError(error.getMessage());
            }
        });
    }

    /** Load a single patient by ID. */
    public void loadPatientById(String patientId, OnPatientLoaded callback) {
        Log.d(TAG, "Loading patient: " + patientId);
        db.child("patients").child(patientId).child("profile")
                .addListenerForSingleValueEvent(new ValueEventListener() {
                    @Override
                    public void onDataChange(@NonNull DataSnapshot snapshot) {
                        Patient p = snapshot.getValue(Patient.class);
                        if (p != null) {
                            Log.d(TAG, "Found patient: " + p.patientId + " / " + p.name);
                            callback.onLoaded(p);
                        } else {
                            Log.e(TAG, "Patient not found: " + patientId);
                            callback.onError("Patient not found");
                        }
                    }

                    @Override
                    public void onCancelled(@NonNull DatabaseError error) {
                        callback.onError(error.getMessage());
                    }
                });
    }

    // ── Readings ───────────────────────────────────────────────────────

    /** Overwrite latest vitals. */
    public void updateLatest(String patientId, Reading r, OnCompleteCallback callback) {
        Log.d(TAG, "Updating latest for: " + patientId);
        db.child("patients").child(patientId).child("latest").setValue(r.toMap())
                .addOnSuccessListener(unused -> {
                    if (callback != null) callback.onSuccess();
                })
                .addOnFailureListener(e -> {
                    if (callback != null) callback.onError(e.getMessage());
                });
    }

    /** Push a new saved reading AND update latest. */
    public void saveReading(String patientId, Reading r, OnCompleteCallback callback) {
        Log.d(TAG, "Saving reading for: " + patientId);
        db.child("patients").child(patientId).child("savedReadings")
                .push().setValue(r.toMap())
                .addOnSuccessListener(unused -> {
                    Log.d(TAG, "Reading saved OK, updating latest...");
                    updateLatest(patientId, r, callback);
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Reading save FAILED: " + e.getMessage());
                    if (callback != null) callback.onError(e.getMessage());
                });
    }

    /** Load saved readings for a patient. */
    public void loadSavedReadings(String patientId, OnReadingsLoaded callback) {
        Log.d(TAG, "Loading saved readings for: " + patientId);
        db.child("patients").child(patientId).child("savedReadings")
                .addListenerForSingleValueEvent(new ValueEventListener() {
                    @Override
                    public void onDataChange(@NonNull DataSnapshot snapshot) {
                        List<Reading> list = new ArrayList<>();
                        for (DataSnapshot ds : snapshot.getChildren()) {
                            Reading r = ds.getValue(Reading.class);
                            if (r != null) list.add(r);
                        }
                        Log.d(TAG, "Loaded " + list.size() + " readings");
                        callback.onLoaded(list);
                    }

                    @Override
                    public void onCancelled(@NonNull DatabaseError error) {
                        callback.onError(error.getMessage());
                    }
                });
    }
    // ── Medicines ───────────────────────────────────────────────────────

    public interface OnMedicinesLoaded {
        void onLoaded(List<com.robot.patientmonitor.models.Medicine> medicines);
        void onError(String message);
    }

    public void addMedicine(String patientId, com.robot.patientmonitor.models.Medicine medicine, OnCompleteCallback callback) {
        DatabaseReference medRef = db.child("patients").child(patientId).child("medicines").push();
        medicine.medicineId = medRef.getKey();
        medRef.setValue(medicine.toMap())
                .addOnSuccessListener(unused -> { if (callback != null) callback.onSuccess(); })
                .addOnFailureListener(e -> { if (callback != null) callback.onError(e.getMessage()); });
    }

    public void loadMedicines(String patientId, OnMedicinesLoaded callback) {
        db.child("patients").child(patientId).child("medicines")
                .addListenerForSingleValueEvent(new ValueEventListener() {
                    @Override
                    public void onDataChange(@NonNull DataSnapshot snapshot) {
                        List<com.robot.patientmonitor.models.Medicine> list = new ArrayList<>();
                        for (DataSnapshot ds : snapshot.getChildren()) {
                            com.robot.patientmonitor.models.Medicine m = ds.getValue(com.robot.patientmonitor.models.Medicine.class);
                            if (m != null) list.add(m);
                        }
                        callback.onLoaded(list);
                    }

                    @Override
                    public void onCancelled(@NonNull DatabaseError error) {
                        callback.onError(error.getMessage());
                    }
                });
    }

    public void updateMedicineActive(String patientId, String medicineId, boolean active, OnCompleteCallback callback) {
        db.child("patients").child(patientId).child("medicines").child(medicineId).child("active").setValue(active)
                .addOnSuccessListener(unused -> { if (callback != null) callback.onSuccess(); })
                .addOnFailureListener(e -> { if (callback != null) callback.onError(e.getMessage()); });
    }
}
