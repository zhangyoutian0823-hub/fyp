//
//  NoteDetailView.swift
//  iOSFaceRecognition
//
//  加密备忘录详情页：
//  - 标题直接显示，内容默认隐藏（显示占位符）
//  - 点击"Unlock Content"触发人脸验证（FaceAuthSheet）
//  - 验证通过后完整内容显示 + 一键复制，10 秒后自动隐藏
//

import SwiftUI

struct NoteDetailView: View {
    @EnvironmentObject var noteStore:  NoteStore
    @EnvironmentObject var userStore:  UserStore
    @EnvironmentObject var session:    SessionStore
    @EnvironmentObject var logStore:   LogStore
    @Environment(\.dismiss) private var dismiss

    let note: SecureNote

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

    /// Live version of the note (reflects edits).
    private var current: SecureNote {
        guard let uid = session.currentUserId else { return note }
        return noteStore.entries
            .first(where: { $0.id == note.id && $0.userId == uid }) ?? note
    }

    var body: some View {
        List {
            // ── Header ──
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.orange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(current.title)
                        .font(.title3.bold())

                    Spacer()

                    Button {
                        noteStore.toggleFavorite(id: current.id)
                    } label: {
                        Image(systemName: current.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(current.isFavorite ? .yellow : .secondary)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
            }

            // ── Content ──
            Section("Content") {
                if revealed {
                    // Full content — scrollable multi-line
                    Text(current.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)

                    // Copy + Hide row
                    HStack {
                        Button {
                            UIPasteboard.general.string = current.content
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy Content",
                                  systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.bold())
                                .foregroundStyle(copied ? .green : .blue)
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
                        Text("••••••••••••••••••")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))

                        Button {
                            guard let user = currentUser else { return }
                            if user.faceEmbedding == nil || user.faceEmbedding!.isEmpty {
                                revealContent()
                            } else {
                                showFaceAuth = true
                            }
                        } label: {
                            Label("Unlock Content", systemImage: "faceid")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }

            // ── Meta info ──
            Section("Info") {
                LabeledContent("Created") {
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
                    Label("Delete Note", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(current.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showFaceAuth) {
            if let user = currentUser {
                FaceAuthSheet(user: user) {
                    revealContent()
                }
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddEditNoteView(userId: current.userId, existing: current)
                .environmentObject(noteStore)
        }
        .alert("Move to Recently Deleted?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                let title = current.title
                let uid   = current.userId
                noteStore.softDelete(id: current.id)
                logStore.add(userId: uid, eventType: .noteItemDeleted, detail: title)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This note will be moved to Recently Deleted and permanently removed after 30 days.")
        }
        .onDisappear { hideTimer?.invalidate() }
    }

    // MARK: - Reveal + 10-second auto-hide

    private func revealContent() {
        withAnimation { revealed = true }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation { self.revealed = false }
            }
        }
    }
}
