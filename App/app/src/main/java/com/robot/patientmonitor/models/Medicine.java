package com.robot.patientmonitor.models;

import java.util.HashMap;
import java.util.Map;

public class Medicine {
    public String medicineId;
    public String name;
    public String dose;
    public String notes;
    public boolean active;
    public long createdAt;

    public Medicine() {
        // Default constructor required for calls to DataSnapshot.getValue(Medicine.class)
    }

    public Medicine(String medicineId, String name, String dose, String notes, boolean active, long createdAt) {
        this.medicineId = medicineId;
        this.name = name;
        this.dose = dose;
        this.notes = notes;
        this.active = active;
        this.createdAt = createdAt;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> result = new HashMap<>();
        result.put("medicineId", medicineId);
        result.put("name", name);
        result.put("dose", dose);
        result.put("notes", notes);
        result.put("active", active);
        result.put("createdAt", createdAt);
        return result;
    }
}
