//
//  AdminPanelView.swift
//  iOSFaceRecognition
//
//  Admin dashboard — stat cards, user management, invite code generation.
//

import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var adminStore: AdminStore
    @EnvironmentObject var logStore: LogStore

    @State private var keyword = ""
    @State private var generatedInviteCode: String? = nil
    @State private var showInviteSheet = false

    var filtered: [AppUser] {
        if keyword.isEmpty { return userStore.users }
        return userStore.users.filter {
            $0.userId.localizedCaseInsensitiveContains(keyword) ||
            $0.name.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ── Admin header banner ──
                    adminHeaderBanner

                    VStack(spacing: 20) {
                        // ── Stat cards ──
                        statCards

                        // ── User section ──
                        userSection

                        // ── Actions ──
                        actionSection

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showInviteSheet) {
                inviteCodeSheet
            }
        }
    }

    // MARK: - Admin Header Banner

    @ViewBuilder
    private var adminHeaderBanner: some View {
        if let adminId = session.currentUserId,
           let admin = adminStore.findAdmin(adminId: adminId) {
            ZStack(alignment: .bottom) {
                LinearGradient.appHeroIndigo
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "person.badge.shield.checkmark")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(admin.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Admin · \(admin.adminId)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                    Image(systemName: "shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.18))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Stat Cards

    @ViewBuilder
    private var statCards: some View {
        HStack(spacing: 12) {
            StatCard(title: "Users", value: "\(userStore.users.count)",
                     icon: "person.2.fill", color: .blue)
            StatCard(title: "Logs", value: "\(logStore.logs.count)",
                     icon: "list.bullet.clipboard.fill", color: .orange)
            StatCard(title: "Today", value: "\(todayLoginCount())",
                     icon: "calendar", color: .green)
        }
    }

    // MARK: - User Section

    @ViewBuilder
    private var userSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Registered Users")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Search by name or ID…", text: $keyword)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !keyword.isEmpty {
                    Button { keyword = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if filtered.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text(keyword.isEmpty ? "No users registered" : "No matching users")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                AppCard {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, user in
                        VStack(spacing: 0) {
                            userRow(user)
                            if idx < filtered.count - 1 {
                                Divider().padding(.leading, 72)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func userRow(_ user: AppUser) -> some View {
        HStack(spacing: 12) {
            // Avatar initial
            ZStack {
                Circle()
                    .fill(user.role == .vip ? Color.yellow.opacity(0.20) : Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(user.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(user.role == .vip ? .orange : .blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(user.role.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(user.role == .vip ? Color.yellow.opacity(0.22) : Color.blue.opacity(0.12))
                        .foregroundStyle(user.role == .vip ? Color.orange : Color.blue)
                        .clipShape(Capsule())
                }
                Text("ID: \(user.userId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: user.faceEmbedding != nil ? "faceid" : "faceid")
                        .font(.caption2)
                        .foregroundStyle(user.faceEmbedding != nil ? .green : .red)
                    Text(user.faceEmbedding != nil ? "Face enrolled" : "No face")
                        .font(.caption2)
                        .foregroundStyle(user.faceEmbedding != nil ? .green : .red)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                NavigationLink(destination: AdminUserDetailView(user: user)) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button(role: .destructive) {
                    userStore.deleteUser(userId: user.userId)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Action Section

    @ViewBuilder
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            AppCard {
                NavigationLink(destination: LogListView()) {
                    actionRow(icon: "list.bullet.clipboard.fill", color: .orange,
                              title: "Access Logs", badge: "\(logStore.logs.count)")
                }
                Divider().padding(.leading, 56)
                Button { generateInviteCode() } label: {
                    actionRow(icon: "ticket.fill", color: .purple,
                              title: "Generate Invite Code")
                }
            }

            // Sign Out
            AppCard {
                Button(role: .destructive) {
                    session.logout()
                } label: {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                                .frame(width: 32, height: 32)
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        Text("Sign Out")
                            .font(.body)
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private func actionRow(icon: String, color: Color, title: String, badge: String? = nil) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Invite Code Generation

    private func generateInviteCode() {
        guard let adminId = session.currentUserId else { return }
        AdminInviteService.shared.cleanExpired()
        let invite = AdminInviteService.shared.generate(by: adminId)
        generatedInviteCode = invite.code
        showInviteSheet = true
    }

    // MARK: - Invite Code Sheet

    @ViewBuilder
    private var inviteCodeSheet: some View {
        VStack(spacing: 24) {
            // Drag handle
            Capsule()
                .fill(Color(uiColor: .tertiaryLabel))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "ticket.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.purple)
            }

            VStack(spacing: 6) {
                Text("Admin Invite Code")
                    .font(.title2.bold())
                Text("Share this code with the new admin candidate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let code = generatedInviteCode {
                Text(code)
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .tracking(10)
                    .foregroundStyle(.purple)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 28)
                    .background(Color.purple.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.purple.opacity(0.25), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copy Code", systemImage: "doc.on.doc")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
            }

            // Info list
            VStack(alignment: .leading, spacing: 10) {
                infoRow(icon: "clock", text: "Valid for 24 hours only")
                infoRow(icon: "1.circle", text: "Single use — expires after registration")
                infoRow(icon: "person.crop.circle.badge.checkmark", text: "Share only with trusted individuals")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)

            Button("Done") { showInviteSheet = false }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func todayLoginCount() -> Int {
        let cal = Calendar.current
        return logStore.logs.filter {
            $0.eventType.isSuccess && cal.isDateInToday($0.timestamp)
        }.count
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            VStack(spacing: 20) {
                // ── Avatar header card ──
                VStack(spacing: 10) {
                    if let fn = user.faceImageFilename,
                       let img = userStore.loadImage(filename: fn) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 3))
                    } else {
                        ZStack {
                            Circle()
                                .fill(user.role == .vip ? Color.yellow.opacity(0.20) : Color.blue.opacity(0.12))
                                .frame(width: 90, height: 90)
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(user.role == .vip ? .orange : .blue)
                        }
                    }
                    Text(user.name)
                        .font(.title3.bold())
                    Text("ID: \(user.userId)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(user.role.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(user.role == .vip ? Color.yellow.opacity(0.22) : Color.blue.opacity(0.12))
                        .foregroundStyle(user.role == .vip ? Color.orange : Color.blue)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // ── Account Details ──
                VStack(alignment: .leading, spacing: 0) {
                    Text("Account Details")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 4)

                    AppCard {
                        detailRow(label: "Joined",
                                  value: user.createdAt.formatted(date: .long, time: .shortened))
                        Divider().padding(.leading, 16)
                        detailRow(label: "Face",
                                  value: user.faceEmbedding != nil
                                    ? "Enrolled (\(user.faceEmbedding!.count)D)"
                                    : "Not registered",
                                  valueColor: user.faceEmbedding != nil ? .green : .red)
                        Divider().padding(.leading, 16)
                        detailRow(label: "Password",
                                  value: user.passwordHash != nil ? "Set (SHA-256)" : "Not set",
                                  valueColor: user.passwordHash != nil ? .green : .orange)
                    }
                }

                // ── Recent Activity ──
                if !recentLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Recent Activity")
                            .font(.footnote.bold())
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 4)

                        AppCard {
                            ForEach(Array(recentLogs.enumerated()), id: \.element.id) { idx, log in
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(log.eventType.isSuccess
                                                      ? Color.green.opacity(0.15)
                                                      : Color.red.opacity(0.15))
                                                .frame(width: 34, height: 34)
                                            Image(systemName: log.eventType.icon)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(log.eventType.isSuccess ? .green : .red)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(log.eventType.rawValue)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            Text(log.timestamp.formatted(date: .abbreviated, time: .standard))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if let score = log.similarityScore {
                                            Text(String(format: "%.0f%%", score * 100))
                                                .font(.caption.bold())
                                                .foregroundStyle(score >= FaceMatchService.shared.threshold
                                                                 ? .green : .red)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    if idx < recentLogs.count - 1 {
                                        Divider().padding(.leading, 62)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
