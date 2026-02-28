//
//  AdminLoginView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

//
//  AdminLoginView.swift
//  iOSFaceRecognition
//

import SwiftUI

struct AdminLoginView: View {
    @EnvironmentObject var adminStore: AdminStore
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var adminId: String = ""
    @State private var password: String = ""
    @State private var errorMsg: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Admin Login")
                    .font(.title2).bold()

                TextField("Admin ID", text: $adminId)
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

                Button("Login with Face Recognition") {
                    errorMsg = nil

                    guard let admin = adminStore.findAdmin(adminId: adminId) else {
                        errorMsg = "Admin ID not found. Please register first."
                        return
                    }
                    guard admin.password == password else {
                        errorMsg = "Wrong password."
                        return
                    }
                    guard admin.faceImageFilename != nil else {
                        errorMsg = "No face registered for this admin account."
                        return
                    }
                    guard camera.faceDetected else {
                        errorMsg = "No face detected. Please face the camera."
                        return
                    }

                    session.loginAdmin(adminId: adminId)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Admin Login")
        .navigationBarTitleDisplayMode(.inline)
    }
}
