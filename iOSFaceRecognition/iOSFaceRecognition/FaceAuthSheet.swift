//
//  FaceAuthSheet.swift
//  iOSFaceRecognition
//
//  可复用的人脸二次认证底部弹窗。
//  用于密码管理器"查看明文密码"等需要额外验证的场景。
//

import SwiftUI
import UIKit

private let authHaptic = UINotificationFeedbackGenerator()

struct FaceAuthSheet: View {
    /// 当前登录用户（用于取出 faceEmbedding 做比对）
    let user: AppUser
    /// 验证通过回调
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()

    @State private var livenessVerified = false
    @State private var isProcessing     = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── 说明文字 ──
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Face Verification Required")
                                .font(.subheadline.bold())
                            Text("Confirm your identity to view the password.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // ── 摄像头 ──
                    ZStack {
                        CameraView(service: camera)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        FaceOverlayView(
                            observations: camera.faceObservations,
                            previewLayer: camera.previewLayer
                        )
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        ScannerBracketShape()
                            .stroke(
                                camera.faceDetected ? Color.blue : Color.white.opacity(0.4),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(height: 260)
                            .animation(.easeInOut(duration: 0.25), value: camera.faceDetected)

                        VStack {
                            HStack {
                                Label(
                                    camera.faceDetected ? "Face Detected" : "No Face",
                                    systemImage: camera.faceDetected
                                        ? "checkmark.circle.fill" : "circle.dashed"
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
                        }
                        .padding(12)
                    }

                    // ── 活体状态 ──
                    HStack(spacing: 8) {
                        Image(systemName: livenessVerified
                              ? "checkmark.circle.fill" : "eye.circle")
                            .foregroundStyle(livenessVerified ? .green : .orange)
                        Text(livenessVerified
                             ? "Liveness verified"
                             : "Please blink once to verify liveness")
                            .font(.caption.bold())
                            .foregroundStyle(livenessVerified ? .green : .orange)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background((livenessVerified ? Color.green : Color.orange).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .animation(.easeInOut(duration: 0.2), value: livenessVerified)

                    // ── 错误信息 ──
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
                            Text("Verifying…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // ── 验证按钮 ──
                    Button {
                        Task { await verify() }
                    } label: {
                        Label("Verify & Reveal Password", systemImage: "faceid")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                    .disabled(!camera.faceDetected || !livenessVerified || isProcessing)

                    Spacer(minLength: 8)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Identity Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear  { camera.start(); camera.resetBlink() }
            .onDisappear { camera.stop() }
            .onChange(of: camera.blinkCount) { _, count in
                if count >= 1 && !livenessVerified {
                    withAnimation { livenessVerified = true }
                    authHaptic.notificationOccurred(.success)
                }
            }
        }
    }

    // MARK: - 人脸验证逻辑

    private func verify() async {
        errorMsg = nil
        guard camera.faceDetected else {
            errorMsg = "No face detected. Please face the camera."
            return
        }
        guard let storedEmbedding = user.faceEmbedding, !storedEmbedding.isEmpty else {
            errorMsg = "No face data found for this account."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        // 拍照
        camera.lastPhoto = nil
        camera.capture()
        var waited = 0
        while camera.lastPhoto == nil && waited < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }
        guard let photo = camera.lastPhoto else {
            errorMsg = "Failed to capture photo. Please try again."
            return
        }

        // 提取特征向量
        guard let queryEmbedding = await FaceEmbeddingService.shared.extractEmbedding(from: photo) else {
            errorMsg = "Could not read face. Ensure good lighting and face the camera directly."
            authHaptic.notificationOccurred(.error)
            return
        }

        // 1:1 比对当前用户
        let matched = FaceMatchService.shared.match(
            query: queryEmbedding,
            against: storedEmbedding
        )

        if matched {
            authHaptic.notificationOccurred(.success)
            dismiss()
            onSuccess()
        } else {
            authHaptic.notificationOccurred(.error)
            let score = FaceMatchService.shared.similarity(
                queryEmbedding, storedEmbedding
            )
            errorMsg = String(
                format: "Face not recognized (%.0f%% match, %.0f%% required). Try again.",
                score * 100,
                FaceMatchService.shared.threshold * 100
            )
            camera.resetBlink()
            livenessVerified = false
        }
    }
}
