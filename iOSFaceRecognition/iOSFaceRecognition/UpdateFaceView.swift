//
//  UpdateFaceView.swift
//  iOSFaceRecognition
//
//  Update registered face — multi-frame capture with consistent camera UI.
//

import SwiftUI

struct UpdateFaceView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var capturedImages: [UIImage] = []
    @State private var errorMsg: String?
    @State private var isProcessing = false

    private let requiredFrames = 3

    var canCapture: Bool { camera.faceDetected && capturedImages.count < requiredFrames && !isProcessing }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Info banner ──
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Update Face Biometrics")
                            .font(.subheadline.bold())
                        Text("Capture \(requiredFrames) clear frames of your face. Your previous face data will be replaced.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // ── Progress bar ──
                VStack(spacing: 6) {
                    HStack {
                        Text("Captured \(capturedImages.count) of \(requiredFrames) frames")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(capturedImages.count >= requiredFrames
                             ? "Ready ✓"
                             : "\(requiredFrames - capturedImages.count) more needed")
                            .font(.caption.bold())
                            .foregroundStyle(capturedImages.count >= requiredFrames ? .green : .secondary)
                    }
                    ProgressView(value: Double(capturedImages.count), total: Double(requiredFrames))
                        .tint(.blue)
                }

                // ── Camera frame ──
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
                    }
                    .padding(12)
                }

                // ── Thumbnail strip ──
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
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .offset(x: 4, y: 4)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // ── Feedback ──
                if let camErr = camera.lastError {
                    feedbackBanner(text: camErr, color: .orange)
                }
                if let errorMsg {
                    feedbackBanner(text: errorMsg, color: .red)
                }
                if isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Updating face data…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ── Capture + Reset ──
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
                            .background(canCapture ? Color.blue : Color.blue.opacity(0.35))
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

                // ── Confirm ──
                Button {
                    Task { await confirmUpdate() }
                } label: {
                    Label("Confirm Update", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(capturedImages.count >= requiredFrames && !isProcessing
                                    ? Color.blue : Color(uiColor: .systemFill))
                        .foregroundStyle(capturedImages.count >= requiredFrames && !isProcessing
                                         ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(capturedImages.count < requiredFrames || isProcessing)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Update Face")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.lastPhoto) { _, newPhoto in
            if let img = newPhoto, capturedImages.count < requiredFrames {
                capturedImages.append(img)
                camera.lastPhoto = nil
            }
        }
    }

    // MARK: - Helpers

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

    private func confirmUpdate() async {
        errorMsg = nil
        guard let uid = session.currentUserId else { errorMsg = "No session."; return }
        guard capturedImages.count >= requiredFrames else {
            errorMsg = "Please capture \(requiredFrames) frames."
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await userStore.updateFace(userId: uid, faceImages: capturedImages)
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
