//
//  UpdateFaceView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI

struct UpdateFaceView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var camera = CameraService()

    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Update Face")
                .font(.title3).bold()

            CameraView(service: camera)
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(camera.faceDetected ? "✅ Face Detected" : "⬜ No Face")
                .foregroundStyle(camera.faceDetected ? .green : .secondary)

            if let camErr = camera.lastError {
                Text(camErr).foregroundStyle(.orange)
            }

            if let errorMsg {
                Text(errorMsg).foregroundStyle(.red)
            }

            HStack {
                Button("Capture") {
                    errorMsg = nil
                    camera.capture()
                }
                .buttonStyle(.bordered)

                Spacer()

                if camera.lastPhoto != nil {
                    Text("📸 Captured").foregroundStyle(.secondary)
                }
            }

            Button("Confirm Update") {
                errorMsg = nil

                guard let uid = session.currentUserId else {
                    errorMsg = "No logged-in user."
                    return
                }
                guard camera.faceDetected else {
                    errorMsg = "No face detected. Please face the camera."
                    return
                }
                guard let img = camera.lastPhoto else {
                    errorMsg = "Please tap Capture first."
                    return
                }

                do {
                    try userStore.updateFace(userId: uid, faceImage: img)
                    dismiss()
                } catch {
                    errorMsg = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .navigationTitle("Update Face")
        .navigationBarTitleDisplayMode(.inline)
    }
}
