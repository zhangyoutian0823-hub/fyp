//
//  iOSFaceRecognitionApp.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

//
//  iOSFaceRecognitionApp.swift
//  iOSFaceRecognition
//

import SwiftUI

@main
struct iOSFaceRecognitionApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var userStore = UserStore()
    @StateObject private var adminStore = AdminStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(userStore)
                .environmentObject(adminStore)
        }
    }
}

