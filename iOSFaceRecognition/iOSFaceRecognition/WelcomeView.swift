//
//  WelcomeView.swift
//  iOSFaceRecognition
//
//  User home screen — profile card header + Settings-style action list.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore

    var body: some View {
        NavigationStack {
            if let uid = session.currentUserId,
               let user = userStore.findUser(userId: uid) {
                ScrollView {
                    VStack(spacing: 0) {
                        // ── Profile header card ──
                        profileHeader(user: user)

                        // ── Quick Actions ──
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account")
                                .font(.footnote.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)
                                .padding(.top, 28)
                                .padding(.bottom, 4)

                            AppCard {
                                NavigationLink(destination: UpdateFaceView()) {
                                    actionRow(icon: "faceid", color: .blue, title: "Update Face")
                                }
                                Divider().padding(.leading, 56)
                                NavigationLink(destination: UpdatePasswordView()) {
                                    actionRow(icon: "lock.rotation", color: .orange, title: "Change Password")
                                }
                            }
                            .padding(.horizontal, 16)

                            // Sign Out card
                            AppCard {
                                Button(role: .destructive) {
                                    session.logout()
                                } label: {
                                    HStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.red)
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(.white)
                                        }
                                        Text("Sign Out")
                                            .font(.body)
                                            .foregroundStyle(.red)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        Spacer(minLength: 40)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationBarHidden(true)

            } else {
                VStack(spacing: 16) {
                    Text("No active session").foregroundStyle(.secondary)
                    Button("Back to Home") { session.logout() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Profile Header

    @ViewBuilder
    private func profileHeader(user: AppUser) -> some View {
        ZStack(alignment: .bottom) {
            // Gradient banner
            LinearGradient.appHeroBlue
                .frame(height: 180)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                // Avatar
                ZStack {
                    if let fn = user.faceImageFilename,
                       let img = userStore.loadImage(filename: fn) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                            .frame(width: 88, height: 88)
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color(uiColor: .systemBackground), lineWidth: 3)
                )
                .offset(y: 44)
            }
        }
        // White section below banner
        VStack(spacing: 6) {
            Spacer().frame(height: 50) // space for avatar offset
            Text(user.name)
                .font(.title3.bold())
            Text("ID: \(user.userId)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // Role badge
            Text(user.role.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    user.role == .vip
                    ? Color.yellow.opacity(0.22)
                    : Color.blue.opacity(0.12)
                )
                .foregroundStyle(
                    user.role == .vip ? Color.orange : Color.blue
                )
                .clipShape(Capsule())
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Action Row

    private func actionRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
