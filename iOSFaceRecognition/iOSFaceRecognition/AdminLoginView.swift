//
//  AdminLoginView.swift
//  iOSFaceRecognition
//
//  管理员纯人脸认证登录界面（无密码）。
//

import SwiftUI

struct AdminLoginView: View {
    @EnvironmentObject var adminStore: AdminStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var logStore: LogStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var adminId: String = ""
    @State private var errorMsg: String?
    @State private var isProcessing = false
    @State private var lastScore: Float?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Admin Login")
                    .font(.title2).bold()

                TextField("Admin ID", text: $adminId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isProcessing)

                ZStack(alignment: .topLeading) {
                    CameraView(service: camera)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    FaceOverlayView(observations: camera.faceObservations)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            camera.faceDetected ? "Face Detected" : "No Face",
                            systemImage: camera.faceDetected ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(camera.faceDetected ? .green : .secondary)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if let score = lastScore {
                            Text(String(format: "Similarity: %.1f%%", score * 100))
                                .font(.caption.bold())
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(10)
                }

                if let camErr = camera.lastError {
                    Text(camErr).foregroundStyle(.orange).font(.caption)
                }
                if let errorMsg {
                    Text(errorMsg).foregroundStyle(.red).font(.caption)
                }
                if isProcessing { ProgressView("Verifying…") }

                Button {
                    Task { await verifyFace() }
                } label: {
                    Label("Verify Admin Face", systemImage: "person.badge.shield.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!camera.faceDetected || isProcessing ||
                          adminId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Admin Login")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func verifyFace() async {
        errorMsg = nil
        lastScore = nil
        let aid = adminId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !aid.isEmpty else { errorMsg = "Please enter Admin ID."; return }

        guard let admin = adminStore.findAdmin(adminId: aid) else {
            logStore.add(userId: aid, eventType: .userNotFound)
            errorMsg = "Admin ID '\(aid)' not found."
            return
        }
        guard let storedEmbedding = admin.faceEmbedding else {
            errorMsg = "No face registered for this admin. Please register first."
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
        guard let photo = camera.lastPhoto else {
            errorMsg = "Failed to capture photo. Try again."
            return
        }

        guard let queryEmbedding = await FaceEmbeddingService.shared.extractEmbedding(from: photo) else {
            logStore.add(userId: aid, eventType: .noFaceDetected)
            errorMsg = "Could not extract face features."
            return
        }

        let score = FaceMatchService.shared.similarity(queryEmbedding, storedEmbedding)
        lastScore = score

        if score >= FaceMatchService.shared.threshold {
            logStore.add(userId: aid, eventType: .adminLoginSuccess, similarityScore: score)
            session.loginAdmin(adminId: aid)
            dismiss()
        } else {
            logStore.add(userId: aid, eventType: .adminLoginFailed, similarityScore: score)
            errorMsg = String(format: "Face not recognized (%.1f%%  < %.0f%% required).",
                              score * 100,
                              FaceMatchService.shared.threshold * 100)
        }
    }
}
