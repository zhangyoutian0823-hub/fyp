//
//  ForgotPasswordView.swift
//  iOSFaceRecognition
//
//  Password reset via face verification — no old password required.
//  Flow: enter User ID → verify face → set new password.
//

import SwiftUI
import UIKit

private let resetHaptic = UINotificationFeedbackGenerator()

struct ForgotPasswordView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var logStore: LogStore
    @Environment(\.dismiss) var dismiss

    /// Pre-filled from the login screen's User ID field.
    var prefillUserId: String = ""

    @StateObject private var camera = CameraService()

    // Step 1 state
    @State private var userId: String = ""
    @State private var lastScore: Float?

    // Step 2 state
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    // Flow control
    @State private var livenessVerified = false
    @State private var faceVerified = false
    @State private var isProcessing = false
    @State private var errorMsg: String?
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Header ──
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: faceVerified ? "lock.open.fill" : "faceid")
                            .font(.system(size: 30))
                            .foregroundStyle(faceVerified ? .green : .blue)
                    }
                    Text(faceVerified ? "Set New Password" : "Verify Your Identity")
                        .font(.title3.bold())
                    Text(faceVerified
                         ? "Face verified. Choose a strong new password."
                         : "Look into the camera to confirm it's you, then reset your password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
                .animation(.easeInOut, value: faceVerified)

                // ── Error banner ──
                if let errorMsg {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMsg)
                    }
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // ── Processing indicator ──
                if isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Verifying face…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ── Step content ──
                if !faceVerified {
                    faceVerificationSection
                } else {
                    newPasswordSection
                }

                Spacer(minLength: 16)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            userId = prefillUserId
            camera.start()
            camera.resetBlink()
        }
        .onDisappear { camera.stop() }
        .onChange(of: camera.blinkCount) { _, count in
            if count >= 1 && !livenessVerified {
                withAnimation { livenessVerified = true }
                resetHaptic.notificationOccurred(.success)
            }
        }
        .alert("Password Updated!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your password has been reset successfully. You can now sign in with your new password.")
        }
    }

    // MARK: - Step 1: Face Verification

    @ViewBuilder
    private var faceVerificationSection: some View {
        VStack(spacing: 16) {

            // User ID input
            VStack(alignment: .leading, spacing: 6) {
                Text("User ID")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextField("Enter your user ID", text: $userId)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isProcessing)
            }

            // Camera view
            ZStack {
                CameraView(service: camera)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                FaceOverlayView(observations: camera.faceObservations)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                ScannerBracketShape()
                    .stroke(
                        camera.faceDetected ? Color.blue : Color.white.opacity(0.5),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(height: 280)
                    .animation(.easeInOut(duration: 0.25), value: camera.faceDetected)

                VStack {
                    HStack {
                        Label(
                            camera.faceDetected ? "Face Detected" : "No Face",
                            systemImage: camera.faceDetected ? "checkmark.circle.fill" : "circle.dashed"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(camera.faceDetected ? .blue : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                        Spacer()
                    }
                    Spacer()
                    if let score = lastScore {
                        HStack {
                            Spacer()
                            Text(String(format: "%.1f%% match", score * 100))
                                .font(.caption.bold())
                                .foregroundStyle(score >= FaceMatchService.shared.threshold ? .green : .red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.45))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(12)
            }

            if let camErr = camera.lastError {
                Text(camErr)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // ── Liveness status bar ──
            HStack(spacing: 8) {
                Image(systemName: livenessVerified
                      ? "checkmark.circle.fill" : "eye.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(livenessVerified ? .green : .orange)
                Text(livenessVerified
                     ? "Liveness verified"
                     : "Please blink once to confirm you're live")
                    .font(.caption.bold())
                    .foregroundStyle(livenessVerified ? .green : .orange)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background((livenessVerified ? Color.green : Color.orange).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.easeInOut(duration: 0.25), value: livenessVerified)

            // Verify button
            Button {
                Task { await verifyFace() }
            } label: {
                Label("Verify Face to Continue", systemImage: "faceid")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!camera.faceDetected || !livenessVerified || isProcessing ||
                      userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Step 2: New Password

    @ViewBuilder
    private var newPasswordSection: some View {
        VStack(spacing: 16) {

            // Verified banner
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Identity verified — choose a new password")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.green.opacity(0.30), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Password fields card
            AppCard {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("New Password")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        SecureField("At least 6 characters", text: $newPassword)
                            .textContentType(.newPassword)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    Divider().padding(.leading, 16)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Password")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        SecureField("Re-enter new password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                }
            }

            // Strength bar
            if !newPassword.isEmpty {
                let strength = passwordStrength(newPassword)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < strength.level
                                  ? strength.color
                                  : Color(uiColor: .tertiarySystemGroupedBackground))
                            .frame(height: 4)
                    }
                    Text(strength.label)
                        .font(.caption2.bold())
                        .foregroundStyle(strength.color)
                }
            }

            // Mismatch hint
            if !confirmPassword.isEmpty && newPassword != confirmPassword {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Passwords do not match")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Save button
            Button { saveNewPassword() } label: {
                Label("Save New Password", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSave ? Color.blue : Color.gray.opacity(0.35))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!canSave)
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    private struct PasswordStrength {
        let level: Int
        let label: String
        let color: Color
    }

    private func passwordStrength(_ pwd: String) -> PasswordStrength {
        let hasUpper  = pwd.contains(where: \.isUppercase)
        let hasDigit  = pwd.contains(where: \.isNumber)
        let hasSymbol = pwd.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) })
        let score = (hasUpper ? 1 : 0) + (hasDigit ? 1 : 0) + (hasSymbol ? 1 : 0)
        if pwd.count < 8 || score == 0 {
            return PasswordStrength(level: 1, label: "Weak",   color: .red)
        } else if score == 1 {
            return PasswordStrength(level: 2, label: "Fair",   color: .orange)
        } else {
            return PasswordStrength(level: 3, label: "Strong", color: .green)
        }
    }

    // MARK: - Face Verification Logic

    private func verifyFace() async {
        errorMsg = nil; lastScore = nil
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { errorMsg = "Please enter your User ID."; return }
        guard let user = userStore.findUser(userId: uid) else {
            errorMsg = "User '\(uid)' not found."
            resetHaptic.notificationOccurred(.error)
            return
        }
        guard user.isActive else {
            errorMsg = "Account is disabled. Contact your administrator."
            resetHaptic.notificationOccurred(.error)
            return
        }
        guard let storedEmbedding = user.faceEmbedding else {
            errorMsg = "No face registered for this account. Contact your administrator."
            return
        }
        guard camera.faceDetected else {
            errorMsg = "No face detected. Please look at the camera."
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        camera.capture()
        var waitCount = 0
        while camera.lastPhoto == nil && waitCount < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waitCount += 1
        }
        guard let photo = camera.lastPhoto else { errorMsg = "Failed to capture photo."; return }
        guard let queryEmbedding = await FaceEmbeddingService.shared.extractEmbedding(from: photo) else {
            errorMsg = "Could not extract face features. Ensure good lighting."
            resetHaptic.notificationOccurred(.error)
            return
        }
        let score = FaceMatchService.shared.similarity(queryEmbedding, storedEmbedding)
        lastScore = score
        if score >= FaceMatchService.shared.threshold {
            resetHaptic.notificationOccurred(.success)
            camera.stop()
            withAnimation { faceVerified = true }
        } else {
            resetHaptic.notificationOccurred(.error)
            errorMsg = String(
                format: "Face not recognized (%.1f%% < %.0f%% required). Please try again.",
                score * 100, FaceMatchService.shared.threshold * 100
            )
        }
    }

    // MARK: - Save Password Logic

    private func saveNewPassword() {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newPassword.count >= 6 else {
            errorMsg = "Password must be at least 6 characters."
            return
        }
        guard newPassword == confirmPassword else {
            errorMsg = "Passwords do not match."
            return
        }
        let newHash = userStore.hashPassword(newPassword)
        userStore.updatePasswordHash(userId: uid, newHash: newHash)
        resetHaptic.notificationOccurred(.success)
        showSuccess = true
    }
}
