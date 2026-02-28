//
//  WelcomeView.swift
//  iOSFaceRecognition
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let uid = session.currentUserId,
                   let user = userStore.findUser(userId: uid) {

                    // 用户头像
                    if let fn = user.faceImageFilename,
                       let img = userStore.loadImage(filename: fn) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                    }

                    Text(user.name)
                        .font(.title2.bold())
                    Text("ID: \(user.userId)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(user.role.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(user.role == .vip ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.15))
                        .clipShape(Capsule())

                    Divider().padding(.horizontal, 40)

                    NavigationLink(destination: UpdateFaceView()) {
                        Label("Update Face", systemImage: "faceid")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    Button(role: .destructive) {
                        session.logout()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)

                } else {
                    Text("No user session").foregroundStyle(.secondary)
                    Button("Back") { session.logout() }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}
