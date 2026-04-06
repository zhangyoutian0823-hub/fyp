//
//  EntryView.swift
//  iOSFaceRecognition
//
//  App landing screen — KeyFace hero + action buttons.
//

import SwiftUI

struct EntryView: View {

    private let accentColor = Color(red: 0.11, green: 0.18, blue: 0.50)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // Full-screen hero gradient
                LinearGradient.appHeroBlue
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Hero ──
                    VStack(spacing: 32) {

                        // App icon — vault shield with concentric glow rings
                        ZStack {
                            ForEach([220, 172, 132, 100], id: \.self) { size in
                                Circle()
                                    .fill(.white.opacity(
                                        size == 220 ? 0.04
                                        : size == 172 ? 0.07
                                        : size == 132 ? 0.11
                                        : 0.18
                                    ))
                                    .frame(width: CGFloat(size), height: CGFloat(size))
                            }
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 52, weight: .light))
                                .foregroundStyle(.white)
                        }

                        // App name + tagline
                        VStack(spacing: 10) {
                            Text("KeyFace")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Your passwords,\nprotected by your face.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }

                        // Feature pills
                        HStack(spacing: 10) {
                            featurePill(icon: "faceid",      label: "Face Auth")
                            featurePill(icon: "key.fill",    label: "Secure Vault")
                            featurePill(icon: "eye.slash",   label: "Private")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // ── Bottom action card ──
                    VStack(spacing: 12) {

                        // Sign In — primary
                        NavigationLink(destination: LoginView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Sign In with Face")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white)
                            .foregroundStyle(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        // Create Account — secondary
                        NavigationLink(destination: RegisterView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 17, weight: .medium))
                                Text("Create Account")
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(accentColor.opacity(0.08))
                            .foregroundStyle(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(accentColor.opacity(0.22), lineWidth: 1)
                            )
                        }

                        // Legal note
                        Text("Face data never leaves your device.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 44)
                    .background(
                        TopRoundedRectangle(radius: 36)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: .black.opacity(0.20), radius: 28, y: -8)
                    )
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Feature Pill

    private func featurePill(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(label)
                .font(.caption2.bold())
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.white.opacity(0.14))
        .clipShape(Capsule())
    }
}
