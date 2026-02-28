//
//  AdminRegisterView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/28.
//

//
//  AdminRegisterView.swift
//  iOSFaceRecognition
//

import SwiftUI

struct AdminRegisterView: View {
    @EnvironmentObject var adminStore: AdminStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var name: String = ""
    @State private var adminId: String = ""
    @State private var password: String = ""
    @State private var errorMsg: String?
    @State private var successMsg: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Admin Register")
                    .font(.title2).bold()

                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)

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

                HStack {
                    Button("Capture Face") {
                        errorMsg = nil
                        successMsg = nil
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

                if let successMsg {
                    Text(successMsg).foregroundStyle(.green)
                }

                Button("Create Admin Account") {
                    errorMsg = nil
                    successMsg = nil

                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        errorMsg = "Please enter your name."
                        return
                    }
                    guard !adminId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        errorMsg = "Please enter Admin ID."
                        return
                    }
                    guard !password.isEmpty else {
                        errorMsg = "Please enter password."
                        return
                    }
                    guard camera.faceDetected else {
                        errorMsg = "No face detected. Please face the camera."
                        return
                    }
                    guard let img = camera.lastPhoto else {
                        errorMsg = "Please tap 'Capture Face' first."
                        return
                    }

                    do {
                        try adminStore.register(name: name, adminId: adminId, password: password, faceImage: img)
                        successMsg = "✅ Admin account created! You can now login."
                        name = ""
                        adminId = ""
                        password = ""
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
        .navigationTitle("Admin Register")
        .navigationBarTitleDisplayMode(.inline)
    }
}
