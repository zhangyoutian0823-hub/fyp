//
//  RootView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        if session.isAdminLoggedIn {
            AdminPanelView()
        } else if session.isLoggedIn {
            WelcomeView()
        } else {
            EntryView()
        }
    }
}

