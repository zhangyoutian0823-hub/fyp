//
//  AddEditWiFiView.swift
//  iOSFaceRecognition
//
//  新增 / 编辑 WiFi 网络的表单视图（Sheet 呈现）。
//  Open 安全类型时自动隐藏密码字段。
//  密码字段复用 PasswordStrengthBar 和 PasswordGeneratorView。
//

import SwiftUI

struct AddEditWiFiView: View {
    @EnvironmentObject var wifiStore: WiFiStore
    @EnvironmentObject var logStore:  LogStore
    @Environment(\.dismiss) private var dismiss

    let userId: String
    var existing: WiFiEntry? = nil

    @State private var networkName    = ""
    @State private var password       = ""
    @State private var securityType   = WiFiSecurity.wpa2
    @State private var notes          = ""
    @State private var isFavorite     = false
    @State private var showPassword   = false
    @State private var showGenerator  = false

    private var isEditing: Bool { existing != nil }
    private var isOpen: Bool { securityType == .open }

    private var canSave: Bool {
        let nameOK = !networkName.trimmingCharacters(in: .whitespaces).isEmpty
        let passOK = isOpen || !password.trimmingCharacters(in: .whitespaces).isEmpty
        return nameOK && passOK
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Network ──
                Section {
                    LabeledContent {
                        TextField("e.g. HomeNetwork, OfficeWiFi", text: $networkName)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } label: {
                        Label("Network Name", systemImage: "wifi")
                    }

                    Picker(selection: $securityType) {
                        ForEach(WiFiSecurity.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    } label: {
                        Label("Security", systemImage: "lock.shield")
                    }
                } header: {
                    Text("Network")
                }

                // ── Password (hidden for Open networks) ──
                if !isOpen {
                    Section {
                        HStack {
                            Label("Password", systemImage: "lock.fill")
                            Spacer()
                            // Show/hide toggle
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            // Generator
                            Button {
                                showGenerator = true
                            } label: {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        if showPassword {
                            TextField("Password", text: $password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("Password", text: $password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        }

                        if !password.isEmpty {
                            PasswordStrengthBar(password: password)
                        }
                    } header: {
                        Text("Security")
                    } footer: {
                        Text("Password is encrypted with Keychain and requires face verification to view.")
                            .font(.caption)
                    }
                }

                // ── Notes ──
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .font(.body)
                } header: {
                    Text("Notes")
                }

                // ── Options ──
                Section {
                    Toggle(isOn: $isFavorite) {
                        Label("Favourite", systemImage: "star")
                    }
                    .tint(.yellow)
                } header: {
                    Text("Options")
                }
            }
            .navigationTitle(isEditing ? "Edit Network" : "New Network")
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
                    showPassword = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func prefill() {
        guard let e = existing else { return }
        networkName  = e.networkName
        password     = e.password
        securityType = e.securityType
        notes        = e.notes
        isFavorite   = e.isFavorite
    }

    private func save() {
        if var e = existing {
            let trimName = networkName.trimmingCharacters(in: .whitespaces)
            let trimPass = isOpen ? "" : password.trimmingCharacters(in: .whitespaces)
            let hasChanges = e.networkName != trimName || e.password != trimPass ||
                             e.securityType != securityType || e.notes != notes ||
                             e.isFavorite != isFavorite
            e.networkName  = trimName
            e.password     = trimPass
            e.securityType = securityType
            e.notes        = notes
            e.isFavorite   = isFavorite
            wifiStore.update(e)
            if hasChanges {
                logStore.add(userId: userId, eventType: .wifiItemEdited, detail: e.networkName)
            }
        } else {
            let entry = WiFiEntry(
                userId:       userId,
                networkName:  networkName.trimmingCharacters(in: .whitespaces),
                password:     isOpen ? "" : password.trimmingCharacters(in: .whitespaces),
                securityType: securityType,
                notes:        notes,
                isFavorite:   isFavorite
            )
            wifiStore.add(entry)
        }
        dismiss()
    }
}
