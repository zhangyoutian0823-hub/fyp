//
//  RegisteriView.swift
//  iOSFaceRecognition
//
//  用户注册界面。要求采集 3 帧人脸图像，提取 embedding 取平均后存储，
//  提高注册质量和后续识别精度。
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var name: String = ""
    @State private var userId: String = ""
    @State private var errorMsg: String?
    @State private var capturedImages: [UIImage] = []
    @State private var isProcessing = false

    private let requiredFrames = 3

    var captureProgress: String { "\(capturedImages.count) / \(requiredFrames)" }
    var canCapture: Bool { camera.faceDetected && capturedImages.count < requiredFrames && !isProcessing }
    var canRegister: Bool { capturedImages.count >= requiredFrames && !isProcessing &&
                            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Register")
                    .font(.title2).bold()

                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .disabled(isProcessing)

                TextField("User ID", text: $userId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isProcessing)

                // 摄像头预览 + overlay
                ZStack(alignment: .topLeading) {
                    CameraView(service: camera)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    FaceOverlayView(observations: camera.faceObservations)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 状态 + 进度
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            camera.faceDetected ? "Face Detected" : "No Face",
                            systemImage: camera.faceDetected ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(camera.faceDetected ? .green : .secondary)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("Captured: \(captureProgress)")
                            .font(.caption.bold())
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(10)
                }

                // 采集进度条
                ProgressView(value: Double(capturedImages.count), total: Double(requiredFrames))
                    .tint(.green)
                    .animation(.easeInOut, value: capturedImages.count)

                HStack {
                    Button {
                        captureFrame()
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
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // 缩略图行
                if !capturedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { i, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        Text("\(i + 1)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .padding(4)
                                            .background(.black.opacity(0.5))
                                            .clipShape(Circle()),
                                        alignment: .bottomTrailing
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if let camErr = camera.lastError {
                    Text(camErr).foregroundStyle(.orange).font(.caption)
                }
                if let errorMsg {
                    Text(errorMsg).foregroundStyle(.red).font(.caption)
                }
                if isProcessing {
                    ProgressView("Extracting face features…")
                }

                Button {
                    Task { await createAccount() }
                } label: {
                    Label(capturedImages.count < requiredFrames
                          ? "Capture \(requiredFrames - capturedImages.count) more frame(s)"
                          : "Create Account",
                          systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canRegister)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: camera.lastPhoto) { _, newPhoto in
            // 当新照片到达时，加入采集列表
            if let img = newPhoto, capturedImages.count < requiredFrames {
                capturedImages.append(img)
                camera.lastPhoto = nil   // reset for next capture
            }
        }
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
        guard capturedImages.count >= requiredFrames else {
            errorMsg = "Please capture \(requiredFrames) face frames first."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await userStore.register(name: trimName,
                                         userId: trimId,
                                         faceImages: capturedImages)
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
