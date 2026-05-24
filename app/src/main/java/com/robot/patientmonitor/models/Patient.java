package com.robot.patientmonitor.models;

import java.util.HashMap;
import java.util.Map;

public class Patient {
    public String patientId;
    public String name;
    public String age;
    public String room;
    public String notes;
    public long createdAt;

    public Patient() {
        // Required for Firebase
    }

    public Patient(String patientId, String name, String age, String room, String notes) {
        this.patientId = patientId;
        this.name = name;
        this.age = age;
        this.room = room;
        this.notes = notes;
        this.createdAt = System.currentTimeMillis();
    }

    public Map<String, Object> toMap() {
        HashMap<String, Object> result = new HashMap<>();
        result.put("patientId", patientId);
        result.put("name", name);
        result.put("age", age);
        result.put("room", room);
        result.put("notes", notes);
        result.put("createdAt", createdAt);
        return result;
    }
}
