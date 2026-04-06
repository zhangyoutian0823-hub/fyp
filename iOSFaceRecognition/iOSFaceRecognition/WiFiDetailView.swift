//
//  WiFiDetailView.swift
//  iOSFaceRecognition
//
//  WiFi 网络详情页：
//  - 网络名、安全类型、备注始终可见
//  - 密码默认隐藏，人脸验证后显示，10 秒自动收起
//  - Open 网络显示"No password (Open Network)"
//

import SwiftUI

struct WiFiDetailView: View {
    @EnvironmentObject var wifiStore:  WiFiStore
    @EnvironmentObject var userStore:  UserStore
    @EnvironmentObject var session:    SessionStore
    @EnvironmentObject var logStore:   LogStore
    @Environment(\.dismiss) private var dismiss

    let entry: WiFiEntry

    @State private var revealed        = false
    @State private var showFaceAuth    = false
    @State private var showEditSheet   = false
    @State private var showDeleteAlert = false
    @State private var hideTimer:      Timer?
    @State private var copied          = false

    private var currentUser: AppUser? {
        guard let uid = session.currentUserId else { return nil }
        return userStore.findUser(userId: uid)
    }

    /// Live version of the entry (reflects edits).
    private var current: WiFiEntry {
        guard let uid = session.currentUserId else { return entry }
        return wifiStore.entries
            .first(where: { $0.id == entry.id && $0.userId == uid }) ?? entry
    }

    var body: some View {
        List {
            // ── Header ──
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "wifi")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.teal.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.networkName)
                            .font(.title3.bold())
                        // Security badge
                        Text(current.securityType.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(securityColor(current.securityType))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(securityColor(current.securityType).opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }

                    Spacer()

                    Button {
                        wifiStore.toggleFavorite(id: current.id)
                    } label: {
                        Image(systemName: current.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(current.isFavorite ? .yellow : .secondary)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
            }

            // ── Password ──
            Section("Password") {
                if current.securityType == .open {
                    Label("No password (Open Network)", systemImage: "lock.open")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else if revealed {
                    // Full password revealed
                    Text(current.password)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)

                    HStack {
                        Button {
                            UIPasteboard.general.string = current.password
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy Password",
                                  systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.bold())
                                .foregroundStyle(copied ? .green : .teal)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            withAnimation { revealed = false }
                            hideTimer?.invalidate()
                        } label: {
                            Label("Hide", systemImage: "eye.slash")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Locked state
                    VStack(alignment: .leading, spacing: 10) {
                        Text("••••••••••••••••")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))

                        Button {
                            guard let user = currentUser else { return }
                            if user.faceEmbedding == nil || user.faceEmbedding!.isEmpty {
                                revealPassword()
                            } else {
                                showFaceAuth = true
                            }
                        } label: {
                            Label("Unlock Password", systemImage: "faceid")
                                .font(.subheadline.bold())
                                .foregroundStyle(.teal)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }

            // ── Notes ──
            if !current.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Notes") {
                    Text(current.notes)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }

            // ── Meta info ──
            Section("Info") {
                LabeledContent("Security") {
                    Text(current.securityType.rawValue)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Added") {
                    Text(current.createdAt, style: .date)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Modified") {
                    Text(current.updatedAt, style: .date)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Delete ──
            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Network", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(current.networkName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditSheet = true }
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
        .sheet(isPresented: $showEditSheet) {
            AddEditWiFiView(userId: current.userId, existing: current)
                .environmentObject(wifiStore)
        }
        .alert("Move to Recently Deleted?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                let name = current.networkName
                let uid  = current.userId
                wifiStore.softDelete(id: current.id)
                logStore.add(userId: uid, eventType: .wifiItemDeleted, detail: name)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This network will be moved to Recently Deleted and permanently removed after 30 days.")
        }
        .onDisappear { hideTimer?.invalidate() }
    }

    // MARK: - Reveal + 10-second auto-hide

    private func revealPassword() {
        withAnimation { revealed = true }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation { self.revealed = false }
            }
        }
    }

    private func securityColor(_ type: WiFiSecurity) -> Color {
        switch type {
        case .wpa3: return .green
        case .wpa2: return .blue
        case .wpa:  return .indigo
        case .wep:  return .orange
        case .open: return .red
        }
    }
}
