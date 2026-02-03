//
//  RootView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/1/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        if auth.isLoggedIn {
            HomeView()
        } else {
            LoginView()
        }
    }
}
