//
//  HomeView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/1/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48, weight: .semibold))

                Text("登录成功")
                    .font(.title2).bold()

                Text("当前用户：\(auth.currentUser ?? "-")")
                    .foregroundStyle(.secondary)

                if auth.isFaceBound {
                    Text("已绑定人脸：\(auth.faceBoundUser ?? "-")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    auth.logout()
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle("主页")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#Preview {
    HomeView()
        .environmentObject(AuthStore())
}
