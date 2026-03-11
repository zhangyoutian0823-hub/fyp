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
    @EnvironmentObject var logStore: LogStore

    @State private var showEditName = false
    @State private var editNameText = ""

    var body: some View {
        NavigationStack {
            if let uid = session.currentUserId,
               let user = userStore.findUser(userId: uid) {
                ScrollView {
                    VStack(spacing: 0) {

                        // ── Profile header ──
                        profileHeader(user: user)

                        // ── Last login ──
                        if let info = lastLoginInfo(userId: uid) {
                            HStack(spacing: 6) {
                                Image(systemName: info.icon)
                                    .font(.caption2)
                                Text("Last login: \(info.timeText) · \(info.method)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.top, 14)
                            .padding(.bottom, 2)
                        }

                        // ── Quick Actions ──
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account Settings")
                                .font(.footnote.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)
                                .padding(.top, 22)
                                .padding(.bottom, 4)

                            AppCard {
                                NavigationLink(destination: UpdateFaceView()) {
                                    actionRow(icon: "faceid",
                                              color: Color(red: 0.11, green: 0.18, blue: 0.50),
                                              title: "Update Face ID")
                                }
                                Divider().padding(.leading, 56)
                                NavigationLink(destination: UpdatePasswordView()) {
                                    actionRow(icon: "lock.rotation", color: .orange,
                                              title: "Change Password")
                                }
                                Divider().padding(.leading, 56)
                                NavigationLink(destination: UserActivityView()) {
                                    actionRow(icon: "clock.arrow.circlepath", color: .purple,
                                              title: "Login History")
                                }
                            }
                            .padding(.horizontal, 16)

                            // Sign Out
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

                            // App version footer
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .font(.caption2)
                                Text("FaceVault")
                                    .font(.caption2.bold())
                            }
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                            .padding(.bottom, 8)
                        }

                        Spacer(minLength: 40)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationBarHidden(true)
                .alert("Edit Display Name", isPresented: $showEditName) {
                    TextField("New name", text: $editNameText)
                        .autocorrectionDisabled()
                    Button("Save") {
                        let trimmed = editNameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            userStore.updateName(userId: uid, newName: trimmed)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enter a new display name for your account.")
                }

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
        ZStack(alignment: .top) {

            // Layer 1: gradient banner + white info section
            VStack(spacing: 0) {
                LinearGradient.appHeroBlue
                    .frame(height: 186)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .topTrailing) {
                        // Decorative lock icon watermark
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(.white.opacity(0.06))
                            .padding(.top, 28)
                            .padding(.trailing, 22)
                    }

                VStack(spacing: 6) {
                    Spacer().frame(height: 54)

                    // Name + edit
                    Button {
                        editNameText = user.name
                        showEditName = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(user.name)
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.blue.opacity(0.60))
                        }
                    }

                    Text("@\(user.userId)")
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
                                : Color.blue.opacity(0.10)
                        )
                        .foregroundStyle(user.role == .vip ? .orange : .blue)
                        .clipShape(Capsule())
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemGroupedBackground))
            }

            // Layer 2: avatar overlapping the gradient / white boundary
            ZStack {
                if let fn = user.faceImageFilename,
                   let img = userStore.loadImage(filename: fn) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(LinearGradient.appHeroBlue)
                        .frame(width: 92, height: 92)
                    Text(user.name.prefix(1).uppercased())
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            // White ring then subtle shadow ring for depth
            .overlay(
                Circle()
                    .stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 4)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .padding(.top, 140)
        }
    }

    // MARK: - Last Login Info

    private struct LastLoginInfo {
        let icon: String
        let timeText: String
        let method: String
    }

    private func lastLoginInfo(userId: String) -> LastLoginInfo? {
        let successEvents: Set<AccessEventType> = [.loginSuccess, .passwordLoginSuccess]
        let userLogs = logStore.logs(for: userId).filter { successEvents.contains($0.eventType) }
        guard userLogs.count >= 2 else { return nil }
        let prev   = userLogs[1]
        let method = prev.eventType == .passwordLoginSuccess ? "Password" : "Face ID"
        let icon   = prev.eventType == .passwordLoginSuccess ? "key.horizontal" : "faceid"
        return LastLoginInfo(icon: icon,
                             timeText: relativeTimeString(for: prev.timestamp),
                             method: method)
    }

    private func relativeTimeString(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday \(date.formatted(date: .omitted, time: .shortened))"
        } else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
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
