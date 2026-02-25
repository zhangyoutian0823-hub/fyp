//
//  AdminLoginView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI

struct AdminLoginView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) var dismiss

    @State private var adminId = ""
    @State private var password = ""
    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Admin").font(.title2).bold()
            TextField("Admin ID", text: $adminId).textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password).textFieldStyle(.roundedBorder)

            if let errorMsg { Text(errorMsg).foregroundStyle(.red) }

            Button("Login") {
                if adminId == AdminAccount.adminId && password == AdminAccount.password {
                    session.loginAdmin()
                    dismiss()
                } else {
                    errorMsg = "Admin 账号或密码错误"
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("Admin Login")
        .navigationBarTitleDisplayMode(.inline)
    }
}

