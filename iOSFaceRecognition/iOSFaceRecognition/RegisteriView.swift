//
//  RegisteriView.swift
//  iOSFaceRecognition
//
//  用户注册界面 — 卡片分段式布局，密码 + 人脸采集。
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var name: String = ""
    @State private var userId: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMsg: String?
    @State private var capturedImages: [UIImage] = []
    @State private var capturedQualities: [Float] = []   // VNFaceObservation.confidence per frame
    @State private var pendingQuality: Float = 0.0       // snapshot at capture-button tap
    @State private var isProcessing = false

    /// Triggers navigation to LoginView after successful registration.
    @State private var registrationSucceeded = false
    @State private var registeredUserId = ""

    private let requiredFrames = 3

    // Multi-pose guidance: straight → left → right
    private let poseInstructions: [(icon: String, label: String)] = [
        (icon: "arrow.up.circle.fill",       label: "Frame 1 — Look Straight Ahead"),
        (icon: "arrow.turn.up.left",          label: "Frame 2 — Turn Slightly Left"),
        (icon: "arrow.turn.up.right",         label: "Frame 3 — Turn Slightly Right"),
    ]

    var passwordTooShort: Bool { !password.isEmpty && password.count < 6 }
    var passwordMismatch: Bool { !confirmPassword.isEmpty && password != confirmPassword }

    var canCapture: Bool {
        camera.faceDetected && capturedImages.count < requiredFrames && !isProcessing
    }
    var canRegister: Bool {
        capturedImages.count >= requiredFrames && !isProcessing
        && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && password.count >= 6 && password == confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Step 1: Profile Info ──
                sectionCard(title: "Profile", icon: "person.text.rectangle") {
                    formField(label: "Full Name", placeholder: "Enter your name") {
                        TextField("Enter your name", text: $name)
                            .textInputAutocapitalization(.words)
                    }
                    Divider().padding(.leading, 16)
                    formField(label: "User ID", placeholder: "Choose a unique ID") {
                        TextField("Choose a unique ID", text: $userId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                // ── Step 2: Password ──
                sectionCard(title: "Set Password", icon: "lock") {
                    formField(label: "Password", placeholder: "Min. 6 characters") {
                        SecureField("Min. 6 characters", text: $password)
                    }
                    Divider().padding(.leading, 16)
                    formField(label: "Confirm", placeholder: "Repeat password") {
                        SecureField("Repeat password", text: $confirmPassword)
                    }
                    if passwordTooShort || passwordMismatch {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(passwordTooShort
                                 ? "Password must be at least 6 characters"
                                 : "Passwords do not match")
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    } else if !password.isEmpty && !confirmPassword.isEmpty {
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

                // ── Step 3: Face Capture ──
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Face Capture", icon: "camera.on.rectangle")
                        .padding(.horizontal, 4)

                    // Progress bar
                    VStack(spacing: 6) {
                        HStack {
                            Text("Captured \(capturedImages.count) of \(requiredFrames) frames")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(capturedImages.count >= requiredFrames ? "Ready ✓" : "\(requiredFrames - capturedImages.count) more needed")
                                .font(.caption.bold())
                                .foregroundStyle(capturedImages.count >= requiredFrames ? .green : .secondary)
                        }
                        ProgressView(value: Double(capturedImages.count), total: Double(requiredFrames))
                            .tint(.green)

                        // Average quality indicator
                        if !capturedQualities.isEmpty {
                            let avg = capturedQualities.reduce(0, +) / Float(capturedQualities.count)
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(qualityColor(avg))
                                    .frame(width: 8, height: 8)
                                Text(String(format: "Avg Quality: %.0f%%", avg * 100))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                // Low quality warning
                                if let lowIdx = capturedQualities.indices.first(where: { capturedQualities[$0] < 0.7 }) {
                                    Label("Frame \(lowIdx + 1) low quality", systemImage: "exclamationmark.triangle")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    // Pose guidance card
                    if capturedImages.count < requiredFrames {
                        let pose = poseInstructions[capturedImages.count]
                        HStack(spacing: 10) {
                            Image(systemName: pose.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                            Text(pose.label)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .animation(.easeInOut, value: capturedImages.count)
                    }

                    // Camera
                    ZStack {
                        CameraView(service: camera)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        FaceOverlayView(observations: camera.faceObservations, previewLayer: camera.previewLayer)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        ScannerBracketShape()
                            .stroke(
                                camera.faceDetected ? Color.green : Color.white.opacity(0.5),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(height: 280)

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
                        }
                        .padding(12)
                    }

                    // Captured thumbnails with pose label + quality dot
                    if !capturedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(capturedImages.enumerated()), id: \.offset) { i, img in
                                    VStack(spacing: 4) {
                                        ZStack(alignment: .topLeading) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 64, height: 64)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            // Quality dot (top-left)
                                            if i < capturedQualities.count {
                                                Circle()
                                                    .fill(qualityColor(capturedQualities[i]))
                                                    .frame(width: 10, height: 10)
                                                    .padding(4)
                                            }
                                        }
                                        // Pose label below thumbnail
                                        Text(i == 0 ? "Straight" : i == 1 ? "Left" : "Right")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    // Capture controls
                    HStack(spacing: 12) {
                        Button {
                            errorMsg = nil
                            guard camera.faceDetected else {
                                errorMsg = "No face detected. Please face the camera."
                                return
                            }
                            pendingQuality = camera.currentFaceConfidence
                            camera.capture()
                        } label: {
                            Label("Capture Frame", systemImage: "camera.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(canCapture ? Color.blue : Color.blue.opacity(0.35))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(!canCapture)

                        if !capturedImages.isEmpty {
                            Button {
                                capturedImages = []
                                capturedQualities = []
                                camera.lastPhoto = nil
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 46, height: 46)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }

                // ── Error / Loading ──
                if let camErr = camera.lastError {
                    feedbackBanner(text: camErr, color: .orange)
                }
                if let errorMsg {
                    feedbackBanner(text: errorMsg, color: .red)
                }
                if isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Creating account…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ── Create Account ──
                Button {
                    Task { await createAccount() }
                } label: {
                    Label(
                        capturedImages.count < requiredFrames
                            ? "Capture \(requiredFrames - capturedImages.count) more frame(s)"
                            : "Create Account",
                        systemImage: capturedImages.count < requiredFrames ? "camera" : "person.badge.plus"
                    )
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canRegister ? Color.blue : Color(uiColor: .systemFill))
                    .foregroundStyle(canRegister ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canRegister)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationDestination(isPresented: $registrationSucceeded) {
            LoginView(prefillUserId: registeredUserId)
        }
        .onChange(of: camera.lastPhoto) { _, newPhoto in
            if let img = newPhoto, capturedImages.count < requiredFrames {
                capturedImages.append(img)
                capturedQualities.append(pendingQuality)
                camera.lastPhoto = nil
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: icon)
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 8)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func formField<F: View>(label: String, placeholder: String, @ViewBuilder field: () -> F) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            field()
                .font(.subheadline)
                .disabled(isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func feedbackBanner(text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
        }
        .font(.footnote)
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Returns green / orange / red based on VNFaceObservation confidence.
    private func qualityColor(_ confidence: Float) -> Color {
        if confidence >= 0.9 { return .green }
        if confidence >= 0.7 { return .orange }
        return .red
    }

    // MARK: - Actions

    private func captureFrame() {
        errorMsg = nil
        guard camera.faceDetected else {
            errorMsg = "No face detected. Please face the camera."
            return
        }
        camera.capture()
    }

    private func createAccount() async {
        errorMsg = nil
        let trimName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimId   = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimName.isEmpty else { errorMsg = "Please enter your name."; return }
        guard !trimId.isEmpty   else { errorMsg = "Please enter a User ID."; return }
        guard password.count >= 6 else { errorMsg = "Password must be at least 6 characters."; return }
        guard password == confirmPassword else { errorMsg = "Passwords do not match."; return }
        guard capturedImages.count >= requiredFrames else {
            errorMsg = "Please capture \(requiredFrames) face frames."
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await userStore.register(name: trimName, userId: trimId,
                                         password: password, faceImages: capturedImages)
            // Navigate directly to the login screen with the new User ID pre-filled.
            registeredUserId = trimId
            registrationSucceeded = true
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
