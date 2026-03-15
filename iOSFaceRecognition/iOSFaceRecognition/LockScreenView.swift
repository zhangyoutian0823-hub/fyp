//
//  LockScreenView.swift
//  iOSFaceRecognition
//
//  全屏锁定界面 — 后台时间超过 3 分钟后显示，要求人脸解锁。
//  用户可选择直接登出（回到完整登录流程）。
//

import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var session:   SessionStore
    @EnvironmentObject var userStore: UserStore

    @State private var showFaceAuth = false

    // Look up the currently locked-in user so FaceAuthSheet can compare embeddings.
    private var lockedUser: AppUser? {
        guard let uid = session.currentUserId else { return nil }
        return userStore.findUser(userId: uid)
    }

    var body: some View {
        ZStack {
            // ── Background — mirrors EntryView gradient ──
            LinearGradient.appHeroBlue
                .ignoresSafeArea()

            // Decorative watermark
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 220, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.04))
                .offset(x: 60, y: -80)

            VStack(spacing: 0) {
                Spacer()

                // ── Lock icon ──
                ZStack {
                    // Concentric glow rings
                    ForEach([0.08, 0.05, 0.03], id: \.self) { opacity in
                        Circle()
                            .fill(Color.white.opacity(opacity))
                            .frame(width: 130 + CGFloat((0.08 - opacity) * 400),
                                   height: 130 + CGFloat((0.08 - opacity) * 400))
                    }
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }

                Spacer().frame(height: 36)

                // ── Title ──
                Text("FaceVault Locked")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer().frame(height: 10)

                Text("Verify your face to continue")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer().frame(height: 56)

                // ── Unlock button ──
                Button {
                    showFaceAuth = true
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.10, green: 0.16, blue: 0.50),
                                         Color(red: 0.05, green: 0.07, blue: 0.32)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 36)

                Spacer().frame(height: 20)

                // ── Sign-out fallback ──
                Button("Sign Out") {
                    session.logout()
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.50))

                Spacer()
            }
        }
        // Auto-trigger face auth immediately on appear so the user doesn't need an extra tap.
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showFaceAuth = true
            }
        }
        .sheet(isPresented: $showFaceAuth) {
            if let user = lockedUser {
                FaceAuthSheet(user: user) {
                    session.unlock()
                }
            }
        }
    }
}
