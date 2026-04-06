//
//  iOSFaceRecognitionApp.swift
//  iOSFaceRecognition
//

import SwiftUI
import SwiftData

@main
struct iOSFaceRecognitionApp: App {
    @StateObject private var session       = SessionStore()
    @StateObject private var userStore     = UserStore()
    @StateObject private var logStore      = LogStore()
    @StateObject private var passwordStore = PasswordStore()
    @StateObject private var noteStore     = NoteStore()
    @StateObject private var wifiStore     = WiFiStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(userStore)
                .environmentObject(logStore)
                .environmentObject(passwordStore)
                .environmentObject(noteStore)
                .environmentObject(wifiStore)
        }
    }
}
