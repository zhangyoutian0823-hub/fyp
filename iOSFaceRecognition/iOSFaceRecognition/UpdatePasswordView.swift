//
//  UpdatePasswordView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI

struct UpdatePasswordView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss

    @State private var newPassword = ""
    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Update Password").font(.title3).bold()
            SecureField("New Password", text: $newPassword).textFieldStyle(.roundedBorder)

            if let errorMsg { Text(errorMsg).foregroundStyle(.red) }

            Button("Save") {
                guard let uid = session.currentUserId else { return }
                do {
                    try userStore.updatePassword(userId: uid, newPassword: newPassword)
                    dismiss()
                } catch {
                    errorMsg = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}

