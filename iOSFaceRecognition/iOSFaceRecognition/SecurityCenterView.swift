//
//  SecurityCenterView.swift
//  iOSFaceRecognition
//
//  密码安全中心 — 分析当前用户密码库健康状况：
//  • 弱密码（长度 < 10 或缺乏字符多样性）
//  • 重复密码（多条 entry 使用同一密码）
//  • 过期密码（超过 90 天未更新）
//

import SwiftUI

struct SecurityCenterView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var session: SessionStore

    @State private var entryToFix: PasswordEntry? = nil

    private var userId: String { session.currentUserId ?? "" }

    // MARK: - 分析计算属性

    private var allEntries: [PasswordEntry] {
        passwordStore.entries(for: userId)
    }

    /// 弱密码：长度 < 10 或缺少多样性（无数字/大写/特殊字符）
    private var weakEntries: [PasswordEntry] {
        allEntries.filter { isWeak($0.password) }
    }

    /// 重复密码：与其他条目密码相同
    private var reusedEntries: [PasswordEntry] {
        let counts = Dictionary(grouping: allEntries, by: { $0.password })
        return allEntries.filter { (counts[$0.password]?.count ?? 0) > 1 }
    }

    /// 过期密码：超过 90 天未修改
    private var oldEntries: [PasswordEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return allEntries.filter { $0.updatedAt < cutoff }
    }

    private var totalIssues: Int {
        // 去重：一条 entry 可能同时出现在多个问题分类
        let ids = Set(weakEntries.map(\.id))
            .union(reusedEntries.map(\.id))
            .union(oldEntries.map(\.id))
        return ids.count
    }

    private var isSecure: Bool { totalIssues == 0 && !allEntries.isEmpty }
    private var isEmpty: Bool  { allEntries.isEmpty }

    // MARK: - Body

    var body: some View {
        List {
            // ── 顶部 Banner ──
            Section {
                bannerCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // ── 弱密码 ──
            if !weakEntries.isEmpty {
                issueSection(
                    title: "Weak Passwords",
                    subtitle: "Too short or easy to guess",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    entries: weakEntries
                )
            }

            // ── 重复密码 ──
            if !reusedEntries.isEmpty {
                issueSection(
                    title: "Reused Passwords",
                    subtitle: "Same password used in multiple accounts",
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange,
                    entries: reusedEntries
                )
            }

            // ── 过期密码 ──
            if !oldEntries.isEmpty {
                issueSection(
                    title: "Old Passwords",
                    subtitle: "Not updated in the last 90 days",
                    icon: "clock.badge.exclamationmark.fill",
                    color: .yellow,
                    entries: oldEntries
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Security")
        .sheet(item: $entryToFix) { entry in
            AddEditPasswordView(userId: userId, existing: entry)
                .environmentObject(passwordStore)
        }
    }

    // MARK: - Banner Card

    private var bannerCard: some View {
        HStack(spacing: 16) {
            if isEmpty {
                Image(systemName: "shield")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("No passwords yet")
                        .font(.headline)
                    Text("Add passwords to see your security score.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if isSecure {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("All passwords look secure")
                        .font(.headline)
                    Text("No issues found in your vault.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalIssues) issue\(totalIssues == 1 ? "" : "s") found")
                        .font(.headline)
                    Text("Review and fix the items below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Issue Section Builder

    @ViewBuilder
    private func issueSection(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        entries: [PasswordEntry]
    ) -> some View {
        Section {
            ForEach(entries) { entry in
                issueRow(entry: entry, accentColor: color)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).textCase(nil)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .font(.footnote.bold())
        }
    }

    // MARK: - Issue Row

    @ViewBuilder
    private func issueRow(entry: PasswordEntry, accentColor: Color) -> some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: entry.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(accentColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                Text(entry.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Fix button
            Button {
                entryToFix = entry
            } label: {
                Text("Fix")
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 弱密码判定

    private func isWeak(_ password: String) -> Bool {
        if password.count < 10 { return true }
        let hasUpper   = password.contains(where: { $0.isUppercase })
        let hasDigit   = password.contains(where: { $0.isNumber })
        let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })
        // 三项满足不到两项视为弱
        return [hasUpper, hasDigit, hasSpecial].filter { $0 }.count < 2
    }
}
