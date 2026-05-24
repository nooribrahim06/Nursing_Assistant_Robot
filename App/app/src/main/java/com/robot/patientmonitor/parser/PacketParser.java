package com.robot.patientmonitor.parser;

import com.robot.patientmonitor.models.Reading;

/**
 * Parses newline-terminated serial packets from the STM32.
 *
 * Expected format:
 *   TYPE=VITALS,PATIENT=001,BPM=82,SPO2=97,BREATH=540,SMOKE=120,MED=300,ALERT=NONE
 *
 * Rules:
 * - Only TYPE=VITALS packets produce a Reading; all others return null.
 * - Splits by comma, then each pair by the FIRST equals sign only.
 * - Unknown fields are silently ignored.
 * - Missing numeric values default to 0.
 * - Missing ALERT defaults to "NONE".
 * - Corrupt/malformed packets never crash — they return null.
 */
public class PacketParser {

    /**
     * @param rawPacket         The raw comma-separated string received from HC-05
     * @param fallbackPatientId Used when the packet has no PATIENT field
     * @return A populated Reading, or null if the packet is not TYPE=VITALS / corrupt
     */
    public static Reading parse(String rawPacket, String fallbackPatientId) {
        if (rawPacket == null || rawPacket.trim().isEmpty()) return null;
        if (!rawPacket.contains("TYPE=VITALS")) return null;

        Reading r = new Reading();
        r.patientId = (fallbackPatientId != null) ? fallbackPatientId : "000";
        r.bpm = 0;
        r.spo2 = 0;
        r.breath = 0;
        r.smoke = 0;
        r.med = 0;
        r.alert = "NONE";

        try {
            String[] parts = rawPacket.split(",");
            for (String part : parts) {
                // Split by first '=' only — protects against values containing '='
                String[] kv = part.split("=", 2);
                if (kv.length != 2) continue;

                String key   = kv[0].trim();
                String value = kv[1].trim();

                switch (key) {
                    case "PATIENT":
                        if (!value.isEmpty()) r.patientId = value;
                        break;
                    case "BPM":
                        r.bpm = safeInt(value);
                        break;
                    case "SPO2":
                        r.spo2 = safeInt(value);
                        break;
                    case "BREATH":
                        r.breath = safeInt(value);
                        break;
                    case "SMOKE":
                        r.smoke = safeInt(value);
                        break;
                    case "MED":
                        int parsedMed = safeInt(value);
                        if (parsedMed > 600 || parsedMed < 0) {
                            r.med = 0;
                        } else {
                            r.med = parsedMed;
                        }
                        break;
                    case "ALERT":
                        if (!value.isEmpty()) r.alert = value;
                        break;
                    // TYPE and any unknown keys are silently skipped
                }
            }
        } catch (Exception e) {
            return null; // corrupt packet — never crash
        }

        r.timestamp = System.currentTimeMillis();
        return r;
    }

    private static int safeInt(String s) {
        if (s == null || s.trim().isEmpty()) return 0;
        try {
            return Integer.parseInt(s.trim());
        } catch (NumberFormatException e) {
            return 0;
        }
    }
}
