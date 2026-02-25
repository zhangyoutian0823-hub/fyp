//
//  WelcomeView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Welcome").font(.title2).bold()

                if let uid = session.currentUserId,
                   let user = userStore.findUser(userId: uid) {
                    Text("Name: \(user.name)")
                    Text("User ID: \(user.userId)").foregroundStyle(.secondary)

                    if let fn = user.faceImageFilename,
                       let img = userStore.loadImage(filename: fn) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    NavigationLink("Update Face") { UpdateFaceView() }
                        .buttonStyle(.borderedProminent)

                    NavigationLink("Update Password") { UpdatePasswordView() }
                        .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        session.logout()
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                } else {
                    Text("No user").foregroundStyle(.secondary)
                    Button("Back") { session.logout() }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}

