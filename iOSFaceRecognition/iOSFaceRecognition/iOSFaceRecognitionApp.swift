//
//  iOSFaceRecognitionApp.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI

@main
struct iOSFaceRecognitionApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var userStore = UserStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(userStore)
        }
    }
}

