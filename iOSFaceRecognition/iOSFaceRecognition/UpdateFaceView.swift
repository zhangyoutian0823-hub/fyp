//
//  UpdateFaceView.swift
//  iOSFaceRecognition
//
//  更新用户人脸（多帧采集，重新提取 embedding）。
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
        VStack(spacing: 16) {
            Text("Update Face")
                .font(.title3).bold()

            ZStack(alignment: .topLeading) {
                CameraView(service: camera)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                FaceOverlayView(observations: camera.faceObservations)
                    .frame(height: 300)
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

                    Text("Captured: \(capturedImages.count) / \(requiredFrames)")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(10)
            }

            ProgressView(value: Double(capturedImages.count), total: Double(requiredFrames))
                .tint(.green)

            if let camErr = camera.lastError { Text(camErr).foregroundStyle(.orange).font(.caption) }
            if let errorMsg { Text(errorMsg).foregroundStyle(.red).font(.caption) }
            if isProcessing { ProgressView("Processing…") }

            HStack {
                Button {
                    errorMsg = nil
                    camera.capture()
                } label: {
                    Label("Capture Frame", systemImage: "camera.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCapture)

                Spacer()

                if !capturedImages.isEmpty {
                    Button(role: .destructive) {
                        capturedImages = []
                        camera.lastPhoto = nil
                    } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(.bordered)
                }
            }

            Button {
                Task { await confirmUpdate() }
            } label: {
                Label("Confirm Update", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(capturedImages.count < requiredFrames || isProcessing)

            Spacer()
        }
        .padding()
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Update Face")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: camera.lastPhoto) { _, newPhoto in
            if let img = newPhoto, capturedImages.count < requiredFrames {
                capturedImages.append(img)
                camera.lastPhoto = nil
            }
        }
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
