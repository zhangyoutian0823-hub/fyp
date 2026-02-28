//
//  LoginView.swift
//  iOSFaceRecognition
//
//  纯人脸识别认证界面。用户输入 ID 后，对准摄像头拍照，
//  系统提取人脸 embedding 并与注册时的 embedding 进行余弦相似度对比。
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var logStore: LogStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var userId: String = ""
    @State private var errorMsg: String?
    @State private var isProcessing = false
    @State private var lastScore: Float?   // 上次匹配得分（调试/展示用）

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Face Recognition Login")
                    .font(.title2).bold()

                TextField("User ID", text: $userId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isProcessing)

                // 摄像头预览 + 实时 overlay
                ZStack(alignment: .topLeading) {
                    CameraView(service: camera)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    FaceOverlayView(observations: camera.faceObservations)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 状态提示
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

                if isProcessing {
                    ProgressView("Verifying face…")
                }

                Button {
                    Task { await verifyFace() }
                } label: {
                    Label("Verify Face", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!camera.faceDetected || isProcessing ||
                          userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Face Verification

    private func verifyFace() async {
        errorMsg = nil
        lastScore = nil
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !uid.isEmpty else {
            errorMsg = "Please enter your User ID."
            return
        }

        guard let user = userStore.findUser(userId: uid) else {
            logStore.add(userId: uid, eventType: .userNotFound)
            errorMsg = "User '\(uid)' not found."
            return
        }

        guard let storedEmbedding = user.faceEmbedding else {
            errorMsg = "No face registered for this account. Please register first."
            return
        }

        guard camera.faceDetected else {
            errorMsg = "No face detected. Please face the camera."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        // 拍照
        camera.capture()
        // 等待照片
        var waitCount = 0
        while camera.lastPhoto == nil && waitCount < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
            waitCount += 1
        }

        guard let photo = camera.lastPhoto else {
            errorMsg = "Failed to capture photo. Try again."
            return
        }

        // 提取当前人脸 embedding
        guard let queryEmbedding = await FaceEmbeddingService.shared.extractEmbedding(from: photo) else {
            logStore.add(userId: uid, eventType: .noFaceDetected)
            errorMsg = "Could not extract face features. Ensure your face is clearly visible."
            return
        }

        // 余弦相似度匹配
        let score = FaceMatchService.shared.similarity(queryEmbedding, storedEmbedding)
        lastScore = score
        let matched = score >= FaceMatchService.shared.threshold

        if matched {
            logStore.add(userId: uid, eventType: .loginSuccess, similarityScore: score)
            session.loginUser(userId: uid)
            dismiss()
        } else {
            logStore.add(userId: uid, eventType: .faceMatchFailed, similarityScore: score)
            errorMsg = String(format: "Face not recognized (%.1f%% < %.0f%% required).",
                              score * 100,
                              FaceMatchService.shared.threshold * 100)
        }
    }
}
