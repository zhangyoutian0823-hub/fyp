//
//  AdminLoginView.swift
//  iOSFaceRecognition
//
//  管理员纯人脸认证登录界面（高安全性，无密码备选）。
//

import SwiftUI
import UIKit

private let adminHaptic = UINotificationFeedbackGenerator()

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
            VStack(spacing: 24) {

                // ── Admin ID ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("Admin ID")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("Enter your admin ID", text: $adminId)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isProcessing)
                }

                // ── Camera ──
                VStack(spacing: 12) {
                    ZStack {
                        CameraView(service: camera)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        FaceOverlayView(observations: camera.faceObservations)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        ScannerBracketShape()
                            .stroke(
                                camera.faceDetected ? Color.purple : Color.white.opacity(0.5),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(height: 300)
                            .animation(.easeInOut(duration: 0.25), value: camera.faceDetected)

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
                        Text("Verifying identity…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ── Verify button ──
                Button {
                    Task { await verifyFace() }
                } label: {
                    Label("Verify Admin Face", systemImage: "person.badge.shield.checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!camera.faceDetected || isProcessing ||
                          adminId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer(minLength: 16)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Admin Sign In")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private func verifyFace() async {
        errorMsg = nil; lastScore = nil
        let aid = adminId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !aid.isEmpty else { errorMsg = "Please enter Admin ID."; return }
        guard let admin = adminStore.findAdmin(adminId: aid) else {
            logStore.add(userId: aid, eventType: .userNotFound)
            errorMsg = "Admin ID '\(aid)' not found."
            return
        }
        guard let storedEmbedding = admin.faceEmbedding else {
            errorMsg = "No face registered for this admin."
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
            logStore.add(userId: aid, eventType: .noFaceDetected)
            errorMsg = "Could not extract face features."
            return
        }
        let score = FaceMatchService.shared.similarity(queryEmbedding, storedEmbedding)
        lastScore = score
        if score >= FaceMatchService.shared.threshold {
            logStore.add(userId: aid, eventType: .adminLoginSuccess, similarityScore: score)
            adminHaptic.notificationOccurred(.success)
            session.loginAdmin(adminId: aid)
            dismiss()
        } else {
            logStore.add(userId: aid, eventType: .adminLoginFailed, similarityScore: score)
            adminHaptic.notificationOccurred(.error)
            errorMsg = String(format: "Face not recognized (%.1f%% < %.0f%% required).",
                              score * 100, FaceMatchService.shared.threshold * 100)
        }
    }
}
