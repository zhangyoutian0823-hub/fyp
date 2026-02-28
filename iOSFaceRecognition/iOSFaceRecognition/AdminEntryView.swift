//
//  AdminEntryView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/28.
//

//
//  AdminEntryView.swift
//  iOSFaceRecognition
//

import SwiftUI

struct AdminEntryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Admin Portal")
                .font(.title2).bold()

            Text("Please register or login as an admin.\nFace recognition is required.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink("Admin Register") { AdminRegisterView() }
                .buttonStyle(.borderedProminent)

            NavigationLink("Admin Login") { AdminLoginView() }
                .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.inline)
    }
}
