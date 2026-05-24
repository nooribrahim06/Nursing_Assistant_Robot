package com.robot.patientmonitor.models;

import java.util.HashMap;
import java.util.Map;

public class Reading {
    public String patientId;
    public int bpm;
    public int spo2;
    public int breath;
    public int smoke;
    public int med;
    public String alert;
    public long timestamp;

    public Reading() {
        // Required for Firebase
        this.alert = "NONE";
        this.timestamp = System.currentTimeMillis();
    }

    public Map<String, Object> toMap() {
        HashMap<String, Object> result = new HashMap<>();
        result.put("bpm", bpm);
        result.put("spo2", spo2);
        result.put("breath", breath);
        result.put("smoke", smoke);
        result.put("med", med);
        result.put("alert", alert);
        result.put("timestamp", timestamp);
        return result;
    }

    public static String getBreathDescription(int breath) {
        if (breath <= 0) return "No Data";
        if (breath < 12) return "Low";
        if (breath <= 25) return "Normal";
        if (breath <= 60) return "High";
        if (breath < 1000) return "Normal";
        if (breath < 2500) return "Elevated";
        return "High";
    }
}
