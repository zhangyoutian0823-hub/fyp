//
//  SessionStore.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published var currentUserId: String? = nil
    @Published var isAdmin: Bool = false

    var isLoggedIn: Bool { currentUserId != nil && !isAdmin }
    var isAdminLoggedIn: Bool { isAdmin }

    func loginUser(userId: String) {
        currentUserId = userId
        isAdmin = false
    }

    func loginAdmin() {
        currentUserId = nil
        isAdmin = true
    }

    func logout() {
        currentUserId = nil
        isAdmin = false
    }
}


