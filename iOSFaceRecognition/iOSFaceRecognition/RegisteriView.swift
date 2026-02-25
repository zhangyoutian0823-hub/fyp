//
//  RegisteriView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var name: String = ""
    @State private var userId: String = ""
    @State private var password: String = ""
    @State private var errorMsg: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Register")
                    .font(.title2).bold()

                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)

                TextField("User ID", text: $userId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                ZStack(alignment: .topLeading) {
                    CameraView(service: camera)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text(camera.faceDetected ? "✅ Face Detected" : "⬜ No Face")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(10)
                }

                HStack {
                    Button("Capture Face") {
                        errorMsg = nil
                        camera.capture()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    if camera.lastPhoto != nil {
                        Text("📸 Captured")
                            .foregroundStyle(.secondary)
                    }
                }

                if let camErr = camera.lastError {
                    Text(camErr).foregroundStyle(.orange)
                }

                if let errorMsg {
                    Text(errorMsg).foregroundStyle(.red)
                }

                Button("Create Account") {
                    errorMsg = nil

                    // 基础校验
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        errorMsg = "Please enter your name."
                        return
                    }
                    guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        errorMsg = "Please enter User ID."
                        return
                    }
                    guard !password.isEmpty else {
                        errorMsg = "Please enter password."
                        return
                    }

                    // 要求检测到脸 + 已拍照
                    guard camera.faceDetected else {
                        errorMsg = "No face detected. Please face the camera."
                        return
                    }
                    guard let img = camera.lastPhoto else {
                        errorMsg = "Please tap 'Capture Face' first."
                        return
                    }

                    do {
                        try userStore.register(name: name, userId: userId, password: password, faceImage: img)
                        dismiss()
                    } catch {
                        errorMsg = error.localizedDescription
                    }
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
    }
}
