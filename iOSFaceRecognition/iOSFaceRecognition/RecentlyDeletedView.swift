//
//  RecentlyDeletedView.swift
//  iOSFaceRecognition
//
//  最近删除列表：
//  - 展示 30 天内软删除的密码条目
//  - 左滑：恢复 / 永久删除
//  - 工具栏：全部永久删除
//

import SwiftUI

struct RecentlyDeletedView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var session: SessionStore

    @State private var showDeleteAllAlert = false

    private var userId: String { session.currentUserId ?? "" }

    private var deleted: [PasswordEntry] {
        passwordStore.deletedEntries(for: userId)
    }

    var body: some View {
        Group {
            if deleted.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(deleted) { entry in
                            deletedRow(entry)
                        }
                    } header: {
                        Text("Passwords are permanently deleted after 30 days.")
                            .textCase(nil)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !deleted.isEmpty {
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
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(deleted.count) recently deleted passwords. This action cannot be undone.")
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func deletedRow(_ entry: PasswordEntry) -> some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: entry.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.gray.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                Text(entry.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let days = entry.daysSinceDeleted {
                    Text(days == 0 ? "Deleted today"
                         : days == 1 ? "Deleted yesterday"
                         : "Deleted \(days) days ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { passwordStore.restore(id: entry.id) }
            } label: {
                Label("Recover", systemImage: "arrow.uturn.backward.circle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation { passwordStore.hardDelete(id: entry.id) }
            } label: {
                Label("Delete Forever", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("No Recently Deleted Passwords")
                    .font(.title3.bold())
                Text("Deleted passwords are kept here for 30 days before being permanently removed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}
