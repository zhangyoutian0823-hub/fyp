//
//  UpdateFaceView.swift
//  iOSFaceRecognition
//
//  Update registered face — multi-pose guided capture with quality scoring.
//

import SwiftUI

struct UpdateFaceView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var capturedImages: [UIImage] = []
    @State private var capturedQualities: [Float] = []   // VNFaceObservation.confidence per frame
    @State private var pendingQuality: Float = 0.0       // snapshot at capture-button tap
    @State private var errorMsg: String?
    @State private var isProcessing = false

    private let requiredFrames = 3

    // Multi-pose guidance: straight → left → right
    private let poseInstructions: [(icon: String, label: String)] = [
        (icon: "arrow.up.circle.fill",   label: "Frame 1 — Look Straight Ahead"),
        (icon: "arrow.turn.up.left",      label: "Frame 2 — Turn Slightly Left"),
        (icon: "arrow.turn.up.right",     label: "Frame 3 — Turn Slightly Right"),
    ]

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
                        Text("Capture \(requiredFrames) frames following the pose guide. Your previous face data will be replaced.")
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

                // ── Pose guidance card ──
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

                // ── Camera frame ──
                ZStack {
                    CameraView(service: camera)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    FaceOverlayView(observations: camera.faceObservations, previewLayer: camera.previewLayer)
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

                // ── Thumbnail strip with pose label + quality dot ──
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
                capturedQualities.append(pendingQuality)
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

    /// Returns green / orange / red based on VNFaceObservation confidence.
    private func qualityColor(_ confidence: Float) -> Color {
        if confidence >= 0.9 { return .green }
        if confidence >= 0.7 { return .orange }
        return .red
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
