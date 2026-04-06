//
//  PasswordDetailView.swift
//  iOSFaceRecognition
//
//  密码条目详情页：
//  - 所有字段默认展示，密码显示 ••••••••
//  - 点击"查看密码"触发人脸二次验证（FaceAuthSheet）
//  - 验证通过后明文显示，10 秒后自动隐藏
//  - 支持一键复制 username / password / url
//

import SwiftUI

struct PasswordDetailView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var logStore: LogStore
    @Environment(\.dismiss) private var dismiss

    let entry: PasswordEntry

    @State private var showPassword       = false
    @State private var showFaceAuth       = false
    @State private var showFaceAuthForEdit = false
    @State private var showEditSheet      = false
    @State private var showDeleteAlert = false
    @State private var hideTimer: Timer?
    @State private var copiedField: String?   // 用于显示"已复制"气泡

    // 当前登录用户（用于人脸验证）
    private var currentUser: AppUser? {
        guard let uid = session.currentUserId else { return nil }
        return userStore.findUser(userId: uid)
    }

    // 显示的条目（编辑后刷新）——同时校验 userId，防止跨用户读取
    private var current: PasswordEntry {
        guard let uid = session.currentUserId else { return entry }
        return passwordStore.entries
            .first(where: { $0.id == entry.id && $0.userId == uid }) ?? entry
    }

    var body: some View {
        List {
            // ── 图标 + 标题 ──
            Section {
                HStack(spacing: 16) {
                    Image(systemName: current.symbolName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.title)
                            .font(.title3.bold())
                        if !current.url.isEmpty {
                            Text(current.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button {
                        passwordStore.toggleFavorite(id: current.id)
                    } label: {
                        Image(systemName: current.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(current.isFavorite ? .yellow : .secondary)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
            }

            // ── 账号信息 ──
            Section("Account") {
                copyRow(label: "Username",
                        icon: "person",
                        value: current.username,
                        fieldKey: "username")

                // 密码行
                HStack {
                    Label {
                        Text("Password")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "key")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    if showPassword {
                        Text(current.password)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("••••••••")
                            .foregroundStyle(.secondary)
                    }
                    // 复制按钮（仅解锁后显示）
                    if showPassword {
                        copyButton(value: current.password, fieldKey: "password")
                    }
                }

                // 查看 / 隐藏密码按钮
                if showPassword {
                    Button {
                        showPassword = false
                        hideTimer?.invalidate()
                    } label: {
                        Label("Hide Password", systemImage: "eye.slash")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    Button {
                        guard let user = currentUser else { return }
                        // 如果该用户没有人脸数据，直接显示
                        if user.faceEmbedding == nil || user.faceEmbedding!.isEmpty {
                            revealPassword()
                        } else {
                            showFaceAuth = true
                        }
                    } label: {
                        Label("View Password", systemImage: "eye")
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    }
                }
            }

            // ── 网址 ──
            if !current.url.isEmpty {
                Section("Website") {
                    copyRow(label: "URL",
                            icon: "link",
                            value: current.url,
                            fieldKey: "url")
                }
            }

            // ── 备注 ──
            if !current.notes.isEmpty {
                Section("Notes") {
                    Text(current.notes)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }

            // ── 元信息 ──
            Section {
                LabeledContent("Created") {
                    Text(current.createdAt, style: .date)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Modified") {
                    Text(current.updatedAt, style: .date)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Info")
            }

            // ── 删除 ──
            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Password", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(current.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    guard let user = currentUser else { return }
                    if user.faceEmbedding == nil || user.faceEmbedding!.isEmpty {
                        showEditSheet = true
                    } else {
                        showFaceAuthForEdit = true
                    }
                }
            }
        }
        .sheet(isPresented: $showFaceAuth) {
            if let user = currentUser {
                FaceAuthSheet(user: user) {
                    revealPassword()
                }
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showFaceAuthForEdit) {
            if let user = currentUser {
                FaceAuthSheet(user: user) {
                    showEditSheet = true
                }
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddEditPasswordView(userId: current.userId, existing: current)
        }
        .alert("Move to Recently Deleted?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                let title = current.title
                let uid   = current.userId
                passwordStore.softDelete(id: current.id)
                logStore.add(userId: uid, eventType: .vaultItemDeleted, detail: title)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This password will be moved to Recently Deleted and permanently removed after 30 days.")
        }
        // 已复制气泡
        .overlay(alignment: .bottom) {
            if let field = copiedField {
                Text("\(field) copied")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: copiedField)
        .onDisappear { hideTimer?.invalidate() }
    }

    // MARK: - 子组件

    @ViewBuilder
    private func copyRow(label: String, icon: String, value: String, fieldKey: String) -> some View {
        HStack {
            Label {
                Text(label).foregroundStyle(.primary)
            } icon: {
                Image(systemName: icon).foregroundStyle(.blue)
            }
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            copyButton(value: value, fieldKey: label)
        }
    }

    @ViewBuilder
    private func copyButton(value: String, fieldKey: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            withAnimation { copiedField = fieldKey }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { copiedField = nil }
            }
        } label: {
            Image(systemName: "doc.on.doc")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 明文显示 + 10 秒自动隐藏

    private func revealPassword() {
        withAnimation { showPassword = true }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation { showPassword = false }
            }
        }
    }
}
