//
//  LoginView.swift
//  iOSFaceRecognition
//
//  双模式登录界面：人脸识别 或 密码登录。
//

import SwiftUI
import UIKit

private let haptic = UINotificationFeedbackGenerator()

private enum LoginMethod: String, CaseIterable {
    case face     = "Face Login"
    case password = "Password Login"
}

struct LoginView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var logStore: LogStore
    @Environment(\.dismiss) var dismiss

    /// Optionally pre-fill the User ID (e.g. when navigating from RegisterView).
    var prefillUserId: String = ""

    @StateObject private var camera = CameraService()

    @State private var userId: String = ""
    @State private var password: String = ""
    @State private var loginMethod: LoginMethod = .face
    @State private var errorMsg: String?
    @State private var isProcessing = false
    @State private var lastScore: Float?
    @State private var livenessVerified: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Mode selector ──
                HStack(spacing: 0) {
                    ForEach(LoginMethod.allCases, id: \.self) { method in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                loginMethod = method
                                errorMsg = nil
                                lastScore = nil
                                password = ""
                                camera.lastPhoto = nil
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: method == .face ? "faceid" : "lock")
                                    .font(.system(size: 18))
                                Text(method.rawValue)
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                loginMethod == method
                                ? Color(uiColor: .systemBackground)
                                : Color.clear
                            )
                            .foregroundStyle(loginMethod == method ? .blue : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(4)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // ── User ID ──
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

                // ── Mode-specific content ──
                if loginMethod == .face {
                    faceSection
                } else {
                    passwordSection
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
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(loginMethod == .face ? "Verifying face…" : "Verifying password…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 16)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if !prefillUserId.isEmpty { userId = prefillUserId }
            if loginMethod == .face { camera.start(); camera.resetBlink() }
        }
        .onDisappear { camera.stop() }
        .onChange(of: loginMethod) { _, newMethod in
            if newMethod == .face {
                camera.start()
                camera.resetBlink()
                livenessVerified = false
            } else {
                camera.stop()
            }
        }
        // Liveness: mark verified on first detected blink
        .onChange(of: camera.blinkCount) { _, count in
            if count >= 1 && !livenessVerified {
                withAnimation { livenessVerified = true }
                haptic.notificationOccurred(.success)
            }
        }
    }

    // MARK: - Face Login Section

    @ViewBuilder
    private var faceSection: some View {
        VStack(spacing: 12) {
            // Camera frame
            ZStack {
                CameraView(service: camera)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                FaceOverlayView(observations: camera.faceObservations)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Scanner brackets
                ScannerBracketShape()
                    .stroke(
                        camera.faceDetected ? Color.green : Color.white.opacity(0.5),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(height: 300)
                    .animation(.easeInOut(duration: 0.25), value: camera.faceDetected)

                // Status overlay
                VStack {
                    HStack {
                        Label(
                            camera.faceDetected ? "Face Detected" : "No Face",
                            systemImage: camera.faceDetected ? "checkmark.circle.fill" : "circle.dashed"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(camera.faceDetected ? .green : .white)
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
                      ? "checkmark.circle.fill"
                      : "eye.circle")
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

            Button {
                Task { await verifyFace() }
            } label: {
                Label("Verify Face", systemImage: "faceid")
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

    // MARK: - Password Login Section

    @ViewBuilder
    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Password")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink(destination: ForgotPasswordView(prefillUserId: userId)) {
                    HStack(spacing: 3) {
                        Image(systemName: "faceid")
                            .font(.caption2)
                        Text("Forgot password?")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            SecureField("Enter your password", text: $password)
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(isProcessing)
        }

        Button {
            Task { await verifyPassword() }
        } label: {
            Label("Login with Password", systemImage: "key.horizontal")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isProcessing ||
                  userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                  password.isEmpty)
    }

    // MARK: - Face Verification

    private func verifyFace() async {
        errorMsg = nil; lastScore = nil
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { errorMsg = "Please enter your User ID."; return }
        guard let user = userStore.findUser(userId: uid) else {
            logStore.add(userId: uid, eventType: .userNotFound)
            errorMsg = "User '\(uid)' not found."
            haptic.notificationOccurred(.error)
            return
        }
        // ── Account disabled check ──
        guard user.isActive else {
            errorMsg = "Account is disabled. Please contact your administrator."
            haptic.notificationOccurred(.error)
            return
        }
        // ── Lockout check ──
        if userStore.isLocked(userId: uid) {
            let mins = userStore.lockRemainingMinutes(userId: uid)
            errorMsg = "Account locked. Please try again in \(mins) minute\(mins == 1 ? "" : "s")."
            haptic.notificationOccurred(.error)
            return
        }
        guard let storedEmbedding = user.faceEmbedding else {
            errorMsg = "No face registered for this account."
            return
        }
        guard camera.faceDetected else {
            errorMsg = "No face detected. Please face the camera."
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
            logStore.add(userId: uid, eventType: .noFaceDetected)
            errorMsg = "Could not extract face features. Ensure good lighting."
            haptic.notificationOccurred(.error)
            return
        }
        let score = FaceMatchService.shared.similarity(queryEmbedding, storedEmbedding)
        lastScore = score
        if score >= FaceMatchService.shared.threshold {
            userStore.clearFailedAttempts(userId: uid)
            logStore.add(userId: uid, eventType: .loginSuccess, similarityScore: score)
            haptic.notificationOccurred(.success)
            session.loginUser(userId: uid)
            dismiss()
        } else {
            userStore.recordFailedAttempt(userId: uid)
            logStore.add(userId: uid, eventType: .faceMatchFailed, similarityScore: score)
            haptic.notificationOccurred(.error)
            let remaining = userStore.isLocked(userId: uid) ? 0 :
                (5 - (userStore.findUser(userId: uid)?.failedAttempts ?? 0))
            if userStore.isLocked(userId: uid) {
                let mins = userStore.lockRemainingMinutes(userId: uid)
                errorMsg = "Too many failed attempts. Account locked for \(mins) minute\(mins == 1 ? "" : "s")."
            } else {
                errorMsg = String(format: "Face not recognized (%.1f%% < %.0f%% required). %d attempt\(remaining == 1 ? "" : "s") remaining.",
                                  score * 100, FaceMatchService.shared.threshold * 100, remaining)
            }
        }
    }

    // MARK: - Password Verification

    private func verifyPassword() async {
        errorMsg = nil
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { errorMsg = "Please enter your User ID."; return }
        guard !password.isEmpty else { errorMsg = "Please enter your password."; return }
        guard let user = userStore.findUser(userId: uid) else {
            logStore.add(userId: uid, eventType: .userNotFound)
            errorMsg = "User '\(uid)' not found."
            haptic.notificationOccurred(.error)
            return
        }
        // ── Account disabled check ──
        guard user.isActive else {
            errorMsg = "Account is disabled. Please contact your administrator."
            haptic.notificationOccurred(.error)
            return
        }
        // ── Lockout check ──
        if userStore.isLocked(userId: uid) {
            let mins = userStore.lockRemainingMinutes(userId: uid)
            errorMsg = "Account locked. Please try again in \(mins) minute\(mins == 1 ? "" : "s")."
            haptic.notificationOccurred(.error)
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        try? await Task.sleep(nanoseconds: 300_000_000)
        if userStore.verifyPassword(userId: uid, password: password) {
            userStore.clearFailedAttempts(userId: uid)
            logStore.add(userId: uid, eventType: .passwordLoginSuccess)
            haptic.notificationOccurred(.success)
            session.loginUser(userId: uid)
            dismiss()
        } else {
            userStore.recordFailedAttempt(userId: uid)
            logStore.add(userId: uid, eventType: .passwordLoginFailed)
            haptic.notificationOccurred(.error)
            if userStore.isLocked(userId: uid) {
                let mins = userStore.lockRemainingMinutes(userId: uid)
                errorMsg = "Too many failed attempts. Account locked for \(mins) minute\(mins == 1 ? "" : "s")."
            } else {
                let remaining = 5 - (userStore.findUser(userId: uid)?.failedAttempts ?? 0)
                errorMsg = "Incorrect password. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining."
            }
        }
    }
}
