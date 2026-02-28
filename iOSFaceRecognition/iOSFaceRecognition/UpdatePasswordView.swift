//
//  UpdatePasswordView.swift
//  iOSFaceRecognition
//
//  This feature is no longer needed in the pure face recognition system.
//  Kept as an empty view for compatibility.
//

import SwiftUI

struct UpdatePasswordView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Password authentication has been replaced by face recognition.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Back") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Password")
    }
}
