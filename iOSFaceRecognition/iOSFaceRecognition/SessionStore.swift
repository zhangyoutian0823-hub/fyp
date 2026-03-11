//
//  SessionStore.swift
//  iOSFaceRecognition
//
//  Manages current login session and handles 15-minute idle timeout.
//

import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published var currentUserId: String? = nil

    /// Timestamp of the last detected user activity (resets on login or any tap).
    @Published private(set) var lastActivityAt: Date = Date()

    var isLoggedIn: Bool { currentUserId != nil }

    func loginUser(userId: String) {
        currentUserId = userId
        lastActivityAt = Date()
    }

    func logout() {
        currentUserId = nil
    }

    /// Call on any meaningful user interaction to reset the inactivity timer.
    func refreshActivity() {
        guard currentUserId != nil else { return }
        lastActivityAt = Date()
    }

    /// Called periodically by RootView's timer.
    /// Logs out automatically if the user has been idle for more than 15 minutes.
    func checkTimeout() {
        guard currentUserId != nil else { return }
        let idleSeconds = Date().timeIntervalSince(lastActivityAt)
        if idleSeconds > TimeInterval(AppSettings.sessionTimeoutMinutes * 60) {
            logout()
        }
    }
}
