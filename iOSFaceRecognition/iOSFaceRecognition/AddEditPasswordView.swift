//
//  AddEditPasswordView.swift
//  iOSFaceRecognition
//
//  新增 / 编辑密码条目的表单视图（Sheet 呈现）。
//

import SwiftUI

struct AddEditPasswordView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var logStore: LogStore
    @Environment(\.dismiss) private var dismiss

    /// 传入 nil = 新增模式；传入现有条目 = 编辑模式
    let userId: String
    var existing: PasswordEntry? = nil

    // 表单字段
    @State private var title      = ""
    @State private var username   = ""
    @State private var password   = ""
    @State private var url        = ""
    @State private var notes      = ""
    @State private var isFavorite    = false
    @State private var showPassword  = false
    @State private var showGenerator = false

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── 基本信息 ──
                Section {
                    LabeledContent {
                        TextField("e.g. GitHub, Gmail", text: $title)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Title", systemImage: "tag")
                    }

                    LabeledContent {
                        TextField("Username or email", text: $username)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                    } label: {
                        Label("Username", systemImage: "person")
                    }
                } header: {
                    Text("Account")
                }

                // ── 密码 ──
                Section {
                    // Password input row
                    HStack {
                        Label("Password", systemImage: "key")
                        Spacer()
                        if showPassword {
                            TextField("Required", text: $password)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Required", text: $password)
                                .multilineTextAlignment(.trailing)
                        }
                        // Toggle visibility
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        // Open generator
                        Button {
                            showGenerator = true
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    // Strength meter — shown as soon as user starts typing
                    if !password.isEmpty {
                        PasswordStrengthBar(password: password)
                    }
                } header: {
                    Text("Security")
                }

                // ── 可选信息 ──
                Section {
                    LabeledContent {
                        TextField("https://", text: $url)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    } label: {
                        Label("Website", systemImage: "link")
                    }

                    Toggle(isOn: $isFavorite) {
                        Label("Favourite", systemImage: "star")
                    }
                    .tint(.yellow)
                } header: {
                    Text("Details")
                }

                // ── 备注 ──
                Section {
                    TextField("Optional notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle(isEditing ? "Edit Password" : "New Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear { prefill() }
            .sheet(isPresented: $showGenerator) {
                PasswordGeneratorView { generated in
                    password    = generated
                    showPassword = true   // reveal so the user can see what was generated
                }
            }
        }
    }

    // MARK: - Helpers

    private func prefill() {
        guard let e = existing else { return }
        title      = e.title
        username   = e.username
        password   = e.password
        url        = e.url
        notes      = e.notes
        isFavorite = e.isFavorite
    }

    private func save() {
        if var e = existing {
            let trimTitle    = title.trimmingCharacters(in: .whitespaces)
            let trimUsername = username.trimmingCharacters(in: .whitespaces)
            let trimUrl      = url.trimmingCharacters(in: .whitespaces)
            let hasChanges   = e.title != trimTitle || e.username != trimUsername ||
                               e.password != password || e.url != trimUrl ||
                               e.notes != notes || e.isFavorite != isFavorite
            e.title      = trimTitle
            e.username   = trimUsername
            e.password   = password
            e.url        = trimUrl
            e.notes      = notes
            e.isFavorite = isFavorite
            passwordStore.update(e)
            if hasChanges {
                logStore.add(userId: userId,
                             eventType: .vaultItemEdited,
                             detail: e.title)
            }
        } else {
            let entry = PasswordEntry(
                userId:     userId,
                title:      title.trimmingCharacters(in: .whitespaces),
                username:   username.trimmingCharacters(in: .whitespaces),
                password:   password,
                url:        url.trimmingCharacters(in: .whitespaces),
                notes:      notes,
                isFavorite: isFavorite
            )
            passwordStore.add(entry)
        }
        dismiss()
    }
}
