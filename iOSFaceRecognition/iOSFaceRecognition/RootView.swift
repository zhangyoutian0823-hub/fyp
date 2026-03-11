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

    /// Ticks every 60 seconds on the main run loop to check for idle timeout. 没60秒检查一次，检查是否超时
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if session.isLoggedIn {
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
            } else {
                EntryView()
            }
        }
        // Any tap anywhere in the app resets the idle timer.
        .simultaneousGesture(
            TapGesture().onEnded { session.refreshActivity() }  //用户有操作，重置15分钟计时器
        )
        // Every 60 s: log out if idle > 15 min.
        .onReceive(timer) { _ in
            session.checkTimeout()                              //检查是否超过15分钟无操作，超时自动登出
        }
    }
}
