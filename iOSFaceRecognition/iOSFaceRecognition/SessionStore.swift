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
    @Published var isAdmin: Bool = false

    /// Timestamp of the last detected user activity (resets on login or any tap).
    @Published private(set) var lastActivityAt: Date = Date()

    var isLoggedIn: Bool      { currentUserId != nil && !isAdmin }
    var isAdminLoggedIn: Bool { isAdmin }

    func loginUser(userId: String) {
        currentUserId = userId
        isAdmin = false
        lastActivityAt = Date()   // reset idle timer on fresh login
    }

    func loginAdmin(adminId: String) {
        currentUserId = adminId
        isAdmin = true
        lastActivityAt = Date()   // reset idle timer on fresh login
    }

    func logout() {
        currentUserId = nil
        isAdmin = false
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
