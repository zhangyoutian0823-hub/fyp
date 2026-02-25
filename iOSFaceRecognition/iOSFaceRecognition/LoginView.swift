//
//  LoginView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var userId: String = ""
    @State private var password: String = ""
    @State private var errorMsg: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Login")
                    .font(.title2).bold()

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

                if let camErr = camera.lastError {
                    Text(camErr).foregroundStyle(.orange)
                }

                if let errorMsg {
                    Text(errorMsg).foregroundStyle(.red)
                }

                Button("Use Face Recognition") {
                    errorMsg = nil

                    guard let user = userStore.findUser(userId: userId) else {
                        errorMsg = "User not found."
                        return
                    }
                    guard user.password == password else {
                        errorMsg = "Wrong password."
                        return
                    }
                    guard user.faceImageFilename != nil else {
                        errorMsg = "No face registered for this account. Please register first."
                        return
                    }
                    guard camera.faceDetected else {
                        errorMsg = "No face detected. Please face the camera."
                        return
                    }

                    // ✅ 目前实现：检测到脸 + 账号密码正确 -> 登录成功
                    // 🔜 后续可替换成：embedding 比对注册人脸
                    session.loginUser(userId: user.userId)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
    }
}
