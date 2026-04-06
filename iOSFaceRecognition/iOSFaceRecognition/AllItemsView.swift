//
//  AllItemsView.swift
//  iOSFaceRecognition
//
//  汇总视图：将 Passwords、Secure Notes、WiFi Networks 合并展示，
//  支持跨类型搜索。从 Vault 主页"All"卡片进入。
//

import SwiftUI

struct AllItemsView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var noteStore:     NoteStore
    @EnvironmentObject var wifiStore:     WiFiStore
    @EnvironmentObject var session:       SessionStore
    @EnvironmentObject var userStore:     UserStore

    @State private var searchText    = ""

    // Face-auth for password copy
    @State private var copyPasswordTarget: PasswordEntry? = nil
    @State private var showPasswordCopyAuth = false

    // Face-auth for note copy
    @State private var copyNoteTarget: SecureNote? = nil
    @State private var showNoteCopyAuth = false

    // Face-auth for wifi copy
    @State private var copyWifiTarget: WiFiEntry? = nil
    @State private var showWifiCopyAuth = false

    @State private var flashCopied: UUID? = nil

    private var userId: String { session.currentUserId ?? "" }
    private var currentUser: AppUser? { userStore.findUser(userId: userId) }

    // Filtered lists
    private var passwords: [PasswordEntry] {
        passwordStore.entries(for: userId, query: searchText)
    }
    private var notes: [SecureNote] {
        noteStore.notes(for: userId, query: searchText)
    }
    private var wifis: [WiFiEntry] {
        wifiStore.entries(for: userId, query: searchText)
    }

    private var hasAny: Bool { !passwords.isEmpty || !notes.isEmpty || !wifis.isEmpty }
    private var isSearching: Bool { !searchText.isEmpty }

    var body: some View {
        Group {
            if !hasAny && !isSearching {
                emptyState
            } else {
                List {
                    // ── Passwords ──
                    if !passwords.isEmpty {
                        Section("Passwords") {
                            ForEach(passwords) { passwordRow($0) }
                        }
                    }

                    // ── Secure Notes ──
                    if !notes.isEmpty {
                        Section("Secure Notes") {
                            ForEach(notes) { noteRow($0) }
                        }
                    }

                    // ── WiFi Networks ──
                    if !wifis.isEmpty {
                        Section("WiFi Networks") {
                            ForEach(wifis) { wifiRow($0) }
                        }
                    }

                    // ── 搜索无结果 ──
                    if isSearching && !hasAny {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)
                                    Text("No results for \"\(searchText)\"")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 24)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("All")
        .searchable(text: $searchText, prompt: "Search")
        // Password copy auth
        .sheet(isPresented: $showPasswordCopyAuth) {
            if let entry = copyPasswordTarget, let user = currentUser {
                FaceAuthSheet(user: user) {
                    UIPasteboard.general.string = entry.password
                    flash(id: entry.id)
                    copyPasswordTarget = nil
                }
            }
        }
        // Note copy auth
        .sheet(isPresented: $showNoteCopyAuth) {
            if let note = copyNoteTarget, let user = currentUser {
                FaceAuthSheet(user: user) {
                    UIPasteboard.general.string = note.content
                    flash(id: note.id)
                    copyNoteTarget = nil
                }
            }
        }
        // WiFi copy auth
        .sheet(isPresented: $showWifiCopyAuth) {
            if let entry = copyWifiTarget, let user = currentUser {
                FaceAuthSheet(user: user) {
                    UIPasteboard.general.string = entry.password
                    flash(id: entry.id)
                    copyWifiTarget = nil
                }
            }
        }
    }

    // MARK: - Password Row

    @ViewBuilder
    private func passwordRow(_ entry: PasswordEntry) -> some View {
        NavigationLink {
            PasswordDetailView(entry: entry)
        } label: {
            HStack(spacing: 14) {
                iconBadge(symbol: entry.symbolName, color: .blue, id: entry.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.body)
                    Text(entry.username)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                copyPasswordTarget = entry
                showPasswordCopyAuth = true
            } label: {
                Label("Copy Password", systemImage: "key.fill")
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                UIPasteboard.general.string = entry.username
                flash(id: entry.id)
            } label: {
                Label("Copy Username", systemImage: "person.circle.fill")
            }
            .tint(.blue)
        }
    }

    // MARK: - Note Row

    @ViewBuilder
    private func noteRow(_ note: SecureNote) -> some View {
        NavigationLink {
            NoteDetailView(note: note)
        } label: {
            HStack(spacing: 14) {
                iconBadge(symbol: "note.text", color: .orange, id: note.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title).font(.body)
                    Text(notePreview(note.content))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                copyNoteTarget = note
                showNoteCopyAuth = true
            } label: {
                Label("Copy Content", systemImage: "doc.on.doc")
            }
            .tint(.orange)
        }
    }

    // MARK: - WiFi Row

    @ViewBuilder
    private func wifiRow(_ entry: WiFiEntry) -> some View {
        NavigationLink {
            WiFiDetailView(entry: entry)
        } label: {
            HStack(spacing: 14) {
                iconBadge(symbol: "wifi", color: .teal, id: entry.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.networkName).font(.body)
                    Text(entry.securityType.rawValue)
                        .font(.caption)
                        .foregroundStyle(wifiSecurityColor(entry.securityType))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(
                            wifiSecurityColor(entry.securityType).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                if entry.securityType == .open {
                    UIPasteboard.general.string = ""
                    flash(id: entry.id)
                } else {
                    copyWifiTarget = entry
                    showWifiCopyAuth = true
                }
            } label: {
                Label("Copy Password", systemImage: "wifi")
            }
            .tint(.teal)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                UIPasteboard.general.string = entry.networkName
                flash(id: entry.id)
            } label: {
                Label("Copy SSID", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
    }

    // MARK: - Shared icon badge with flash

    @ViewBuilder
    private func iconBadge(symbol: String, color: Color, id: UUID) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if flashCopied == id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .background(Color.green, in: Circle())
                    .offset(x: 4, y: 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: flashCopied)
    }

    // MARK: - Helpers

    private func flash(id: UUID) {
        withAnimation { flashCopied = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { if flashCopied == id { flashCopied = nil } }
        }
    }

    private func notePreview(_ content: String) -> String {
        let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "No content" }
        let limit = clean.index(clean.startIndex, offsetBy: min(60, clean.count))
        return clean.count > 60 ? String(clean[..<limit]) + "…" : clean
    }

    private func wifiSecurityColor(_ type: WiFiSecurity) -> Color {
        switch type {
        case .wpa3: return .green
        case .wpa2: return .blue
        case .wpa:  return .indigo
        case .wep:  return .orange
        case .open: return .red
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))
            VStack(spacing: 6) {
                Text("Nothing Saved Yet")
                    .font(.title3.bold())
                Text("Add passwords, notes, or WiFi networks\nto see them here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}
