//
//  RootView.swift
//  iOSFaceRecognition
//
//  Top-level router — directs to lock screen, user home, or entry screen.
//  • 15-minute idle timer: logs out if the user stops interacting.
//  • Background lock: if the app is backgrounded for ≥ 3 minutes the
//    session is locked and LockScreenView is shown on return.
//

import SwiftUI
import Combine

struct RootView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    /// Timestamp recorded when the app enters the background.
    @State private var backgroundedAt: Date? = nil

    /// How long in the background before requiring face re-verification (3 min).
    private let backgroundLockThreshold: TimeInterval = 3 * 60

    /// Ticks every 60 seconds on the main run loop to check for idle timeout.
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if session.isLoggedIn {
                if session.isLocked {
                    LockScreenView()
                } else {
                    TabView {
                        WelcomeView()
                            .tabItem {
                                Label("Account", systemImage: "person.crop.circle")
                            }
                        PasswordVaultView()
                            .tabItem {
                                Label("Passwords", systemImage: "key.fill")
                            }
                    }
                }
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
        // Background lock: record when the app leaves, check duration on return.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = Date()
            case .active:
                if let t = backgroundedAt,
                   Date().timeIntervalSince(t) > backgroundLockThreshold,
                   session.isLoggedIn {
                    session.lock()
                }
                backgroundedAt = nil
            default:
                break
            }
        }
    }
}
