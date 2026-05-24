package com.robot.patientmonitor.data;

import com.robot.patientmonitor.models.Patient;
import com.robot.patientmonitor.models.Reading;

public class AppState {
    private static AppState instance;
    private Patient selectedPatient;
    private Reading latestReading;

    private AppState() {}

    public static synchronized AppState getInstance() {
        if (instance == null) {
            instance = new AppState();
        }
        return instance;
    }

    public Patient getSelectedPatient() {
        return selectedPatient;
    }

    public void setSelectedPatient(Patient selectedPatient) {
        this.selectedPatient = selectedPatient;
    }

    public Reading getLatestReading() {
        return latestReading;
    }

    public void setLatestReading(Reading latestReading) {
        this.latestReading = latestReading;
    }
}
