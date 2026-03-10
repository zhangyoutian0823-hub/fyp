//
//  AdminRegisterView.swift
//  iOSFaceRecognition
//
//  管理员注册界面 — 卡片分段式布局。
//  首位管理员无需邀请码；后续管理员须持有现有管理员生成的有效邀请码。
//

import SwiftUI

struct AdminRegisterView: View {
    @EnvironmentObject var adminStore: AdminStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var name: String = ""
    @State private var adminId: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var inviteCode: String = ""
    @State private var errorMsg: String?
    @State private var successMsg: String?
    @State private var capturedImages: [UIImage] = []
    @State private var isProcessing = false

    private let requiredFrames = 3

    var canCapture: Bool { camera.faceDetected && capturedImages.count < requiredFrames && !isProcessing }
    var passwordTooShort: Bool { !password.isEmpty && password.count < 6 }
    var passwordMismatch: Bool { !confirmPassword.isEmpty && password != confirmPassword }

    var canRegister: Bool {
        capturedImages.count >= requiredFrames && !isProcessing
        && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !adminId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && password.count >= 6 && password == confirmPassword
        && (adminStore.isFirstSetup || !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Setup mode banner ──
                setupModeBanner

                // ── Profile info ──
                sectionCard(title: "Admin Info", icon: "person.text.rectangle") {
                    formField(label: "Full Name") {
                        TextField("Enter your name", text: $name)
                            .textInputAutocapitalization(.words)
                    }
                    Divider().padding(.leading, 16)
                    formField(label: "Admin ID") {
                        TextField("Choose a unique admin ID", text: $adminId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                // ── Password ──
                sectionCard(title: "Set Password", icon: "lock.shield") {
                    formField(label: "Password") {
                        SecureField("Min. 6 characters", text: $password)
                    }
                    Divider().padding(.leading, 16)
                    formField(label: "Confirm") {
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

                // ── Invite code (non-first admin only) ──
                if !adminStore.isFirstSetup {
                    sectionCard(title: "Invite Code", icon: "ticket") {
                        formField(label: "Code") {
                            TextField("8-character invite code", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .onChange(of: inviteCode) { _, v in
                                    inviteCode = String(v.uppercased().prefix(8))
                                }
                        }
                    }
                }

                // ── Face capture ──
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Face Capture", icon: "camera.on.rectangle")
                        .padding(.horizontal, 4)

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
                            .tint(.purple)
                    }

                    ZStack {
                        CameraView(service: camera)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        FaceOverlayView(observations: camera.faceObservations, previewLayer: camera.previewLayer)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        ScannerBracketShape()
                            .stroke(
                                camera.faceDetected ? Color.purple : Color.white.opacity(0.5),
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
                                .foregroundStyle(camera.faceDetected ? .purple : .white)
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

                    if !capturedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(capturedImages.enumerated()), id: \.offset) { i, img in
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Text("\(i + 1)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Color.purple)
                                            .clipShape(Circle())
                                            .offset(x: 4, y: 4)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            errorMsg = nil
                            guard camera.faceDetected else {
                                errorMsg = "No face detected."
                                return
                            }
                            camera.capture()
                        } label: {
                            Label("Capture Frame", systemImage: "camera.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(canCapture ? Color.purple : Color.purple.opacity(0.35))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(!canCapture)

                        if !capturedImages.isEmpty {
                            Button {
                                capturedImages = []
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

                // ── Feedback ──
                if let camErr = camera.lastError {
                    feedbackBanner(text: camErr, color: .orange)
                }
                if let errorMsg { feedbackBanner(text: errorMsg, color: .red) }
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
                        Text("Creating admin account…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ── Submit ──
                Button {
                    Task { await createAdminAccount() }
                } label: {
                    Label("Create Admin Account", systemImage: "person.badge.shield.checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canRegister ? Color.purple : Color(uiColor: .systemFill))
                        .foregroundStyle(canRegister ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canRegister)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Admin Register")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.lastPhoto) { _, newPhoto in
            if let img = newPhoto, capturedImages.count < requiredFrames {
                capturedImages.append(img)
                camera.lastPhoto = nil
            }
        }
    }

    // MARK: - Setup Mode Banner

    @ViewBuilder
    private var setupModeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: adminStore.isFirstSetup ? "gearshape.2.fill" : "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(adminStore.isFirstSetup ? .blue : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(adminStore.isFirstSetup ? "First Admin Setup" : "Invite Required")
                    .font(.subheadline.bold())
                Text(adminStore.isFirstSetup
                     ? "You are registering as the first system admin — no invite code needed."
                     : "An existing admin must generate an invite code for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(
            (adminStore.isFirstSetup ? Color.blue : Color.orange).opacity(0.10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((adminStore.isFirstSetup ? Color.blue : Color.orange).opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    // MARK: - Actions

    private func createAdminAccount() async {
        errorMsg = nil; successMsg = nil
        let trimName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimId   = adminId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimName.isEmpty else { errorMsg = "Please enter your name."; return }
        guard !trimId.isEmpty   else { errorMsg = "Please enter Admin ID."; return }
        guard password.count >= 6 else { errorMsg = "Password must be at least 6 characters."; return }
        guard password == confirmPassword else { errorMsg = "Passwords do not match."; return }
        guard capturedImages.count >= requiredFrames else {
            errorMsg = "Please capture \(requiredFrames) face frames."; return
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await adminStore.register(
                name: trimName, adminId: trimId, password: password,
                inviteCode: adminStore.isFirstSetup ? nil : trimCode,
                faceImages: capturedImages
            )
            successMsg = "Admin account created! You can now sign in."
            name = ""; adminId = ""; password = ""; confirmPassword = ""
            inviteCode = ""; capturedImages = []
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
