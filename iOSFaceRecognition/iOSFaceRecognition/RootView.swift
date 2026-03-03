//
//  RootView.swift
//  iOSFaceRecognition
//
//  Top-level router — directs to Admin panel, user home, or entry screen.
//  Fires a 60-second timer to enforce the 15-minute idle session timeout.
//

import SwiftUI
import Combine

struct RootView: View {
    @EnvironmentObject var session: SessionStore

    /// Ticks every 60 seconds on the main run loop to check for idle timeout.
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if session.isAdminLoggedIn {
                AdminPanelView()
            } else if session.isLoggedIn {
                WelcomeView()
            } else {
                EntryView()
            }
        }
        // Any tap anywhere in the app resets the idle timer.
        .simultaneousGesture(
            TapGesture().onEnded { session.refreshActivity() }
        )
        // Every 60 s: log out if idle > 15 min.
        .onReceive(timer) { _ in
            session.checkTimeout()
        }
    }
}
