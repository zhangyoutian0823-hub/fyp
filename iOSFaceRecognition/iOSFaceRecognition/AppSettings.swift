//
//  AppSettings.swift
//  iOSFaceRecognition
//
//  Centralised UserDefaults-backed settings — read/written by SystemSettingsView,
//  consumed by FaceMatchService, UserStore, and SessionStore.
//

import Foundation

enum AppSettings {

    // MARK: - Keys

    private enum Key {
        static let faceThreshold       = "settings_face_threshold"
        static let maxFailedAttempts   = "settings_max_failed_attempts"
        static let lockoutMinutes      = "settings_lockout_minutes"
        static let sessionTimeoutMins  = "settings_session_timeout_minutes"
    }

    // MARK: - Face Threshold (0.60 – 0.90, default 0.75)

    static var faceThreshold: Float {
        get {
            let v = UserDefaults.standard.float(forKey: Key.faceThreshold)
            return v == 0 ? 0.75 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.faceThreshold) }
    }

    // MARK: - Max Failed Attempts before lockout (3 – 10, default 5)

    static var maxFailedAttempts: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: Key.maxFailedAttempts)
            return v == 0 ? 5 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.maxFailedAttempts) }
    }

    // MARK: - Lockout Duration in minutes (5 / 10 / 15 / 30, default 15)

    static var lockoutMinutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: Key.lockoutMinutes)
            return v == 0 ? 15 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.lockoutMinutes) }
    }

    // MARK: - Session Idle Timeout in minutes (5 / 15 / 30 / 60, default 15)

    static var sessionTimeoutMinutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: Key.sessionTimeoutMins)
            return v == 0 ? 15 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.sessionTimeoutMins) }
    }

    // MARK: - Reset to defaults

    static func resetToDefaults() {
        faceThreshold      = 0.75
        maxFailedAttempts  = 5
        lockoutMinutes     = 15
        sessionTimeoutMinutes = 15
    }
}
