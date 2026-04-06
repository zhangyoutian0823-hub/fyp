//
//  PasswordVaultView.swift
//  iOSFaceRecognition
//
//  Vault 主页 — 仿 Apple Passwords 风格的分类卡片网格。
//  布局：2×2 网格（密码 / 备忘录 / WiFi / 安全）+ 底部全宽"最近删除"行
//

import SwiftUI

struct PasswordVaultView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var noteStore:     NoteStore
    @EnvironmentObject var wifiStore:     WiFiStore
    @EnvironmentObject var session: SessionStore

    @State private var showAddPassword = false
    @State private var showAddNote     = false
    @State private var showAddWifi     = false

    private var userId: String { session.currentUserId ?? "" }

    // 给 Security 卡片用的问题数（复用 SecurityCenterView 的逻辑）
    private var issueCount: Int {
        let all = passwordStore.entries(for: userId)
        let weak    = all.filter { isWeak($0.password) }
        let reused  = { () -> [PasswordEntry] in
            let counts = Dictionary(grouping: all, by: { $0.password })
            return all.filter { (counts[$0.password]?.count ?? 0) > 1 }
        }()
        let cutoff  = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let old     = all.filter { $0.updatedAt < cutoff }
        let ids = Set(weak.map(\.id)).union(reused.map(\.id)).union(old.map(\.id))
        return ids.count
    }

    private var combinedDeletedCount: Int {
        passwordStore.deletedCount(for: userId)
        + noteStore.deletedCount(for: userId)
        + wifiStore.deletedCount(for: userId)
    }

    private var allCount: Int {
        passwordStore.totalCount(for: userId)
        + noteStore.totalCount(for: userId)
        + wifiStore.totalCount(for: userId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // ── 顶部全宽"All"行 ──
                    NavigationLink {
                        AllItemsView()
                    } label: {
                        AllItemsRow(count: allCount)
                    }
                    .buttonStyle(.plain)

                    // ── 2×2 分类卡片网格 ──
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        // Passwords
                        NavigationLink {
                            AllPasswordsView()
                        } label: {
                            CategoryCard(
                                title: "Passwords",
                                icon: "key.fill",
                                iconColor: .blue,
                                count: passwordStore.totalCount(for: userId)
                            )
                        }
                        .buttonStyle(.plain)

                        // Secure Notes
                        NavigationLink {
                            AllNotesView()
                        } label: {
                            CategoryCard(
                                title: "Secure Notes",
                                icon: "note.text",
                                iconColor: .orange,
                                count: noteStore.totalCount(for: userId)
                            )
                        }
                        .buttonStyle(.plain)

                        // WiFi Networks
                        NavigationLink {
                            AllWiFiView()
                        } label: {
                            CategoryCard(
                                title: "WiFi Networks",
                                icon: "wifi",
                                iconColor: .teal,
                                count: wifiStore.totalCount(for: userId)
                            )
                        }
                        .buttonStyle(.plain)

                        // Security
                        NavigationLink {
                            SecurityCenterView()
                        } label: {
                            CategoryCard(
                                title: "Security",
                                icon: issueCount > 0
                                    ? "exclamationmark.shield.fill"
                                    : "checkmark.shield.fill",
                                iconColor: issueCount > 0 ? .red : .green,
                                count: issueCount
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // ── 底部全宽"最近删除"行 ──
                    NavigationLink {
                        RecentlyDeletedView()
                    } label: {
                        RecentlyDeletedRow(count: combinedDeletedCount)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Vault")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAddPassword = true
                        } label: {
                            Label("New Password", systemImage: "key.fill")
                        }
                        Button {
                            showAddNote = true
                        } label: {
                            Label("New Secure Note", systemImage: "note.text")
                        }
                        Button {
                            showAddWifi = true
                        } label: {
                            Label("New WiFi Network", systemImage: "wifi")
                        }
                    } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddPassword) {
                AddEditPasswordView(userId: userId)
                    .environmentObject(passwordStore)
            }
            .sheet(isPresented: $showAddNote) {
                AddEditNoteView(userId: userId)
                    .environmentObject(noteStore)
            }
            .sheet(isPresented: $showAddWifi) {
                AddEditWiFiView(userId: userId)
                    .environmentObject(wifiStore)
            }
        }
    }

    // MARK: - 弱密码判定（与 SecurityCenterView 保持一致）
    private func isWeak(_ password: String) -> Bool {
        if password.count < 10 { return true }
        let hasUpper   = password.contains(where: { $0.isUppercase })
        let hasDigit   = password.contains(where: { $0.isNumber })
        let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })
        return [hasUpper, hasDigit, hasSpecial].filter { $0 }.count < 2
    }
}

// MARK: - 顶部"All"全宽行

private struct AllItemsRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.purple.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("All")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Text("Passwords · Notes · WiFi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(count)")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

// MARK: - 分类卡片

private struct CategoryCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(iconColor.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Spacer()

                Text("\(count)")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 12)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

// MARK: - 底部"最近删除"全宽行

private struct RecentlyDeletedRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "trash.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.gray.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text("Recently Deleted")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
