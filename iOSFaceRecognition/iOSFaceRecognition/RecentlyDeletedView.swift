//
//  RecentlyDeletedView.swift
//  iOSFaceRecognition
//
//  最近删除列表：
//  - 展示 30 天内软删除的密码、备忘录、WiFi 网络
//  - 左滑：恢复 / 永久删除
//  - 工具栏：全部永久删除
//

import SwiftUI

struct RecentlyDeletedView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var noteStore:     NoteStore
    @EnvironmentObject var wifiStore:     WiFiStore
    @EnvironmentObject var session: SessionStore

    @State private var showDeleteAllAlert = false

    private var userId: String { session.currentUserId ?? "" }

    private var deletedPasswords: [PasswordEntry] { passwordStore.deletedEntries(for: userId) }
    private var deletedNotes:     [SecureNote]     { noteStore.deletedNotes(for: userId) }
    private var deletedWifi:      [WiFiEntry]      { wifiStore.deletedEntries(for: userId) }
    private var hasAny: Bool {
        !deletedPasswords.isEmpty || !deletedNotes.isEmpty || !deletedWifi.isEmpty
    }
    private var totalCount: Int {
        deletedPasswords.count + deletedNotes.count + deletedWifi.count
    }

    var body: some View {
        Group {
            if !hasAny {
                emptyState
            } else {
                List {
                    // ── Passwords ──
                    if !deletedPasswords.isEmpty {
                        Section {
                            ForEach(deletedPasswords) { entry in
                                deletedPasswordRow(entry)
                            }
                        } header: {
                            Text("Passwords — permanently deleted after 30 days.")
                                .textCase(nil)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // ── Notes ──
                    if !deletedNotes.isEmpty {
                        Section {
                            ForEach(deletedNotes) { note in
                                deletedNoteRow(note)
                            }
                        } header: {
                            Text("Secure Notes — permanently deleted after 30 days.")
                                .textCase(nil)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // ── WiFi ──
                    if !deletedWifi.isEmpty {
                        Section {
                            ForEach(deletedWifi) { entry in
                                deletedWifiRow(entry)
                            }
                        } header: {
                            Text("WiFi Networks — permanently deleted after 30 days.")
                                .textCase(nil)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasAny {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All", role: .destructive) {
                        showDeleteAllAlert = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .alert("Delete All Permanently?", isPresented: $showDeleteAllAlert) {
            Button("Delete All", role: .destructive) {
                passwordStore.hardDeleteAllDeleted(for: userId)
                noteStore.hardDeleteAllDeleted(for: userId)
                wifiStore.hardDeleteAllDeleted(for: userId)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(totalCount) recently deleted items. This action cannot be undone.")
        }
    }

    // MARK: - Password Row

    @ViewBuilder
    private func deletedPasswordRow(_ entry: PasswordEntry) -> some View {
        HStack(spacing: 14) {
            Image(systemName: entry.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.gray.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.body)
                Text(entry.username)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                daysLabel(entry.daysSinceDeleted)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { withAnimation { passwordStore.restore(id: entry.id) } }
            label: { Label("Recover", systemImage: "arrow.uturn.backward.circle") }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { withAnimation { passwordStore.hardDelete(id: entry.id) } }
            label: { Label("Delete Forever", systemImage: "trash.fill") }
        }
    }

    // MARK: - Note Row

    @ViewBuilder
    private func deletedNoteRow(_ note: SecureNote) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "note.text")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.gray.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title).font(.body)
                Text("Secure Note")
                    .font(.caption).foregroundStyle(.secondary)
                daysLabel(note.daysSinceDeleted)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { withAnimation { noteStore.restore(id: note.id) } }
            label: { Label("Recover", systemImage: "arrow.uturn.backward.circle") }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { withAnimation { noteStore.hardDelete(id: note.id) } }
            label: { Label("Delete Forever", systemImage: "trash.fill") }
        }
    }

    // MARK: - WiFi Row

    @ViewBuilder
    private func deletedWifiRow(_ entry: WiFiEntry) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "wifi")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.gray.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.networkName).font(.body)
                Text(entry.securityType.rawValue)
                    .font(.caption).foregroundStyle(.secondary)
                daysLabel(entry.daysSinceDeleted)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { withAnimation { wifiStore.restore(id: entry.id) } }
            label: { Label("Recover", systemImage: "arrow.uturn.backward.circle") }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { withAnimation { wifiStore.hardDelete(id: entry.id) } }
            label: { Label("Delete Forever", systemImage: "trash.fill") }
        }
    }

    // MARK: - Shared helper

    @ViewBuilder
    private func daysLabel(_ days: Int?) -> some View {
        if let d = days {
            Text(d == 0 ? "Deleted today"
                 : d == 1 ? "Deleted yesterday"
                 : "Deleted \(d) days ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("No Recently Deleted Items")
                    .font(.title3.bold())
                Text("Deleted passwords, notes, and WiFi networks are kept here for 30 days before being permanently removed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}
