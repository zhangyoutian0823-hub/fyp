//
//  iOSFaceRecognitionApp.swift
//  iOSFaceRecognition
//

import SwiftUI
import SwiftData

@main
struct iOSFaceRecognitionApp: App {
    @StateObject private var session   = SessionStore()
    @StateObject private var userStore = UserStore()
    @StateObject private var adminStore = AdminStore()
    @StateObject private var logStore  = LogStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(userStore)
                .environmentObject(adminStore)
                .environmentObject(logStore)
        }
    }
}
