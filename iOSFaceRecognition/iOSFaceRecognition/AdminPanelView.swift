//
//  AdminPanelView.swift
//  iOSFaceRecognition
//

import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var adminStore: AdminStore
    @EnvironmentObject var logStore: LogStore

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
                // Admin info header
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

                // 快速统计
                HStack(spacing: 16) {
                    StatBadge(title: "Users", value: "\(userStore.users.count)",
                              icon: "person.2", color: .blue)
                    StatBadge(title: "Logs", value: "\(logStore.logs.count)",
                              icon: "list.bullet.clipboard", color: .orange)
                    StatBadge(title: "Today", value: "\(todayLoginCount())",
                              icon: "calendar", color: .green)
                }
                .padding(.horizontal)

                HStack {
                    TextField("Search userId / name", text: $keyword)
                        .textFieldStyle(.roundedBorder)
                    Button("Clear") { keyword = "" }
                }
                .padding(.horizontal)

                List {
                    ForEach(filtered) { u in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(u.name)  (\(u.userId))").bold()
                                Spacer()
                                Text(u.role.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(u.role == .vip ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            HStack {
                                Text("Face: \(u.faceEmbedding == nil ? "Not registered" : "Enrolled")")
                                    .foregroundStyle(u.faceEmbedding == nil ? .red : .secondary)
                                    .font(.caption)
                                Spacer()
                                Text("Joined \(u.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Button(role: .destructive) {
                                    userStore.deleteUser(userId: u.userId)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                        .font(.caption)
                                }

                                Spacer()

                                NavigationLink("View") {
                                    AdminUserDetailView(user: u)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                // 日志入口
                NavigationLink(destination: LogListView()) {
                    Label("Access Logs (\(logStore.logs.count))",
                          systemImage: "list.bullet.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

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

    private func todayLoginCount() -> Int {
        let cal = Calendar.current
        return logStore.logs.filter {
            $0.eventType.isSuccess && cal.isDateInToday($0.timestamp)
        }.count
    }
}

// MARK: - StatBadge

private struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title3.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - AdminUserDetailView

struct AdminUserDetailView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var logStore: LogStore
    let user: AppUser

    var recentLogs: [AccessLog] {
        Array(logStore.logs(for: user.userId).prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 基本信息
                GroupBox("User Information") {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("User ID", value: user.userId)
                    LabeledContent("Role", value: user.role.rawValue)
                    LabeledContent("Joined", value: user.createdAt.formatted(date: .long, time: .shortened))
                    LabeledContent("Face", value: user.faceEmbedding != nil ? "Enrolled (\(user.faceEmbedding!.count)D)" : "Not registered")
                }

                // 人脸图片
                if let fn = user.faceImageFilename,
                   let img = userStore.loadImage(filename: fn) {
                    GroupBox("Registered Face") {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: .infinity)
                    }
                }

                // 最近认证记录
                if !recentLogs.isEmpty {
                    GroupBox("Recent Activity") {
                        ForEach(recentLogs) { log in
                            HStack {
                                Image(systemName: log.eventType.icon)
                                    .foregroundStyle(log.eventType.isSuccess ? .green : .red)
                                VStack(alignment: .leading) {
                                    Text(log.eventType.rawValue).font(.caption)
                                    Text(log.timestamp.formatted(date: .abbreviated, time: .standard))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let score = log.similarityScore {
                                    Text(String(format: "%.0f%%", score * 100))
                                        .font(.caption.bold())
                                        .foregroundStyle(score >= FaceMatchService.shared.threshold ? .green : .red)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
