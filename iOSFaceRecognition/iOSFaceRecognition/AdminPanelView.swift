//
//  AdminPanelView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

//
//  AdminPanelView.swift
//  iOSFaceRecognition
//

import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var adminStore: AdminStore

    @State private var keyword = ""

    var filtered: [AppUser] {
        if keyword.isEmpty { return userStore.users }
        return userStore.users.filter {
            $0.userId.localizedCaseInsensitiveContains(keyword) ||
            $0.name.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Current admin info
                if let adminId = session.currentUserId,
                   let admin = adminStore.findAdmin(adminId: adminId) {
                    HStack {
                        Image(systemName: "person.badge.shield.checkmark")
                            .foregroundStyle(.blue)
                        Text("Logged in as: \(admin.name)  (\(admin.adminId))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                HStack {
                    TextField("Search userId / name", text: $keyword)
                        .textFieldStyle(.roundedBorder)
                    Button("Clear") { keyword = "" }
                }
                .padding(.horizontal)

                List {
                    ForEach(filtered) { u in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(u.name)  (\(u.userId))").bold()
                            Text("Has Face: \(u.faceImageFilename == nil ? "No" : "Yes")")
                                .foregroundStyle(.secondary)

                            HStack {
                                Button(role: .destructive) {
                                    userStore.deleteUser(userId: u.userId)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Spacer()

                                NavigationLink("View") {
                                    AdminUserDetailView(user: u)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Button(role: .destructive) {
                    session.logout()
                } label: {
                    Label("Admin Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding(.top)
            .navigationTitle("Admin Panel")
        }
    }
}

struct AdminUserDetailView: View {
    @EnvironmentObject var userStore: UserStore
    let user: AppUser

    var body: some View {
        VStack(spacing: 12) {
            Text("User Information").font(.title3).bold()
            Text("Name: \(user.name)")
            Text("User ID: \(user.userId)")
            Text("Password: \(user.password)").foregroundStyle(.secondary)

            if let fn = user.faceImageFilename,
               let img = userStore.loadImage(filename: fn) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text("No Face Image").foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}
