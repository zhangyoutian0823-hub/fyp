//
//  UpdatePasswordView.swift
//  iOSFaceRecognition
//
//  Change password — verify current password, then set a new one (≥ 6 characters).
//

import SwiftUI

struct UpdatePasswordView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""
    @State private var errorMsg: String?
    @State private var successMsg: String?
    @State private var isProcessing = false

    var currentUserId: String { session.currentUserId ?? "" }

    var newPasswordTooShort: Bool { !newPassword.isEmpty && newPassword.count < 6 }
    var newPasswordMismatch: Bool { !confirmNewPassword.isEmpty && newPassword != confirmNewPassword }
    var newPasswordGood: Bool {
        !newPassword.isEmpty && !confirmNewPassword.isEmpty
        && !newPasswordTooShort && !newPasswordMismatch
    }

    var canSubmit: Bool {
        !currentPassword.isEmpty
        && newPassword.count >= 6
        && newPassword == confirmNewPassword
        && !isProcessing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Header ──
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    Text("Change Password")
                        .font(.title3.bold())
                    Text("Verify your current password, then set a new one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)

                // ── Current Password card ──
                sectionCard(title: "Current Password", icon: "lock") {
                    formField(label: "Current") {
                        SecureField("Enter current password", text: $currentPassword)
                    }
                }

                // ── New Password card ──
                sectionCard(title: "New Password", icon: "lock.open") {
                    formField(label: "New") {
                        SecureField("Min. 6 characters", text: $newPassword)
                    }
                    Divider().padding(.leading, 16)
                    formField(label: "Confirm") {
                        SecureField("Repeat new password", text: $confirmNewPassword)
                    }
                    if newPasswordTooShort || newPasswordMismatch {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(newPasswordTooShort
                                 ? "Password must be at least 6 characters"
                                 : "New passwords do not match")
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    } else if newPasswordGood {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Password looks good")
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                }

                // ── Feedback ──
                if let errorMsg {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMsg)
                    }
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if let successMsg {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(successMsg)
                    }
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Updating password…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ── Submit ──
                Button {
                    Task { await changePassword() }
                } label: {
                    Label("Update Password", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canSubmit ? Color.orange : Color(uiColor: .systemFill))
                        .foregroundStyle(canSubmit ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSubmit)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String, icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: icon)
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 8)
                .padding(.horizontal, 4)

            VStack(spacing: 0) { content() }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func formField<F: View>(label: String, @ViewBuilder field: () -> F) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            field()
                .font(.subheadline)
                .disabled(isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Actions

    private func changePassword() async {
        errorMsg = nil
        successMsg = nil

        guard userStore.verifyPassword(userId: currentUserId, password: currentPassword) else {
            errorMsg = "Current password is incorrect."
            return
        }
        guard newPassword.count >= 6 else {
            errorMsg = "New password must be at least 6 characters."
            return
        }
        guard newPassword == confirmNewPassword else {
            errorMsg = "New passwords do not match."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        // Brief delay (anti-brute-force UX)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let newHash = userStore.hashPassword(newPassword)
        guard let _ = userStore.users.firstIndex(where: { $0.userId == currentUserId }) else {
            errorMsg = "User not found."
            return
        }

        userStore.updatePasswordHash(userId: currentUserId, newHash: newHash)

        currentPassword = ""
        newPassword = ""
        confirmNewPassword = ""
        successMsg = "Password updated successfully!"
    }
}
