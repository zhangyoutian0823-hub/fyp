//
//  EntryView.swift
//  iOSFaceRecognition
//
//  App landing screen — hero gradient with branding + action buttons.
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
                    // Hero section
                    VStack(spacing: 22) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.05))
                                .frame(width: 168, height: 168)
                            Circle()
                                .fill(.white.opacity(0.09))
                                .frame(width: 130, height: 130)
                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 96, height: 96)
                            Image(systemName: "faceid")
                                .font(.system(size: 50, weight: .light))
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 8) {
                            Text("FaceGuard")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Secure Face Recognition System")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.60))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Bottom action card
                    VStack(spacing: 14) {

                        NavigationLink(destination: RegisterView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Create Account")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white)
                            .foregroundStyle(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        NavigationLink(destination: LoginView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Sign In")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(accentColor.opacity(0.10))
                            .foregroundStyle(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(accentColor.opacity(0.30), lineWidth: 1)
                            )
                        }

                        Rectangle()
                            .fill(Color(uiColor: .separator))
                            .frame(height: 0.5)
                            .padding(.vertical, 2)

                        NavigationLink(destination: AdminEntryView()) {
                            HStack(spacing: 5) {
                                Image(systemName: "lock.shield")
                                    .font(.caption)
                                Text("Admin Portal")
                                    .font(.subheadline)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 6)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 30)
                    .padding(.bottom, 40)
                    .background(
                        TopRoundedRectangle(radius: 32)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: .black.opacity(0.22), radius: 24, y: -6)
                    )
                }
            }
            .navigationBarHidden(true)
        }
    }
}
