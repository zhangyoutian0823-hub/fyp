//
//  AdminRegisterView.swift
//  iOSFaceRecognition
//
//  管理员注册界面（纯人脸，3帧采集）。
//

import SwiftUI

struct AdminRegisterView: View {
    @EnvironmentObject var adminStore: AdminStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var name: String = ""
    @State private var adminId: String = ""
    @State private var errorMsg: String?
    @State private var successMsg: String?
    @State private var capturedImages: [UIImage] = []
    @State private var isProcessing = false

    private let requiredFrames = 3

    var canCapture: Bool { camera.faceDetected && capturedImages.count < requiredFrames && !isProcessing }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Admin Register")
                    .font(.title2).bold()

                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)

                TextField("Admin ID", text: $adminId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

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
                    .tint(.blue)

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

                if let camErr = camera.lastError { Text(camErr).foregroundStyle(.orange).font(.caption) }
                if let errorMsg   { Text(errorMsg).foregroundStyle(.red).font(.caption) }
                if let successMsg { Text(successMsg).foregroundStyle(.green).font(.caption) }
                if isProcessing   { ProgressView("Processing…") }

                Button {
                    Task { await createAdminAccount() }
                } label: {
                    Label("Create Admin Account", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(capturedImages.count < requiredFrames || isProcessing ||
                          name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          adminId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Admin Register")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: camera.lastPhoto) { _, newPhoto in
            if let img = newPhoto, capturedImages.count < requiredFrames {
                capturedImages.append(img)
                camera.lastPhoto = nil
            }
        }
    }

    private func createAdminAccount() async {
        errorMsg = nil; successMsg = nil
        let trimName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimId   = adminId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimName.isEmpty else { errorMsg = "Please enter your name."; return }
        guard !trimId.isEmpty   else { errorMsg = "Please enter Admin ID."; return }
        guard capturedImages.count >= requiredFrames else {
            errorMsg = "Please capture \(requiredFrames) face frames first."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await adminStore.register(name: trimName, adminId: trimId, faceImages: capturedImages)
            successMsg = "Admin account created! You can now login."
            name = ""; adminId = ""; capturedImages = []
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
