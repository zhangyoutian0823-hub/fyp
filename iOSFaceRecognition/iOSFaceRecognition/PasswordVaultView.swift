//
//  PasswordVaultView.swift
//  iOSFaceRecognition
//
//  密码管理主页 — 仿 Apple Passwords 风格的分类卡片网格。
//  卡片入口：全部 / 安全性 / 最近删除
//

import SwiftUI

struct PasswordVaultView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var session: SessionStore

    @State private var showAddSheet = false

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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    // ── 全部 ──
                    NavigationLink {
                        AllPasswordsView()
                    } label: {
                        CategoryCard(
                            title: "All",
                            icon: "key.fill",
                            iconColor: .blue,
                            count: passwordStore.totalCount(for: userId)
                        )
                    }
                    .buttonStyle(.plain)

                    // ── 安全性 ──
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

                    // ── 最近删除 ──
                    NavigationLink {
                        RecentlyDeletedView()
                    } label: {
                        CategoryCard(
                            title: "Recently Deleted",
                            icon: "trash.fill",
                            iconColor: .gray,
                            count: passwordStore.deletedCount(for: userId)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Passwords")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEditPasswordView(userId: userId)
                    .environmentObject(passwordStore)
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

// MARK: - 分类卡片

private struct CategoryCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(iconColor.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Spacer()

                // Count
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
