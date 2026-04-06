//
//  AllNotesView.swift
//  iOSFaceRecognition
//
//  加密备忘录列表：收藏置顶 + 按首字母分组，支持搜索。
//  标题可见；内容前 60 字作为预览（已登录用户可见，完整内容在 NoteDetailView 需要人脸验证）。
//

import SwiftUI

struct AllNotesView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var session:   SessionStore
    @EnvironmentObject var userStore: UserStore

    @State private var searchText    = ""
    @State private var showAddSheet  = false

    // Quick-copy via swipe
    @State private var copyTarget:   SecureNote? = nil
    @State private var showCopyAuth: Bool        = false
    @State private var flashCopied:  UUID?       = nil

    private var userId: String { session.currentUserId ?? "" }
    private var currentUser: AppUser? { userStore.findUser(userId: userId) }

    // 搜索过滤后的活跃条目
    private var filtered: [SecureNote] {
        noteStore.notes(for: userId, query: searchText)
    }

    // 收藏
    private var favorites: [SecureNote] {
        filtered.filter { $0.isFavorite }
    }

    // 非收藏按首字母分组
    private var grouped: [(letter: String, notes: [SecureNote])] {
        let nonFav = filtered.filter { !$0.isFavorite }
        let dict   = Dictionary(grouping: nonFav) { $0.firstLetter }
        return dict.keys.sorted().map { (letter: $0, notes: dict[$0]!) }
    }

    var body: some View {
        Group {
            if filtered.isEmpty && searchText.isEmpty {
                emptyState
            } else {
                List {
                    // ── 收藏夹 ──
                    if !favorites.isEmpty {
                        Section("Favourites") {
                            ForEach(favorites) { noteRow($0) }
                        }
                    }

                    // ── 按字母分组 ──
                    ForEach(grouped, id: \.letter) { group in
                        Section(group.letter) {
                            ForEach(group.notes) { noteRow($0) }
                        }
                    }

                    // ── 搜索无结果 ──
                    if filtered.isEmpty {
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
        .navigationTitle("Secure Notes")
        .searchable(text: $searchText, prompt: "Search")
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
            AddEditNoteView(userId: userId)
                .environmentObject(noteStore)
        }
        // Face-auth sheet for swipe-to-copy content
        .sheet(isPresented: $showCopyAuth) {
            if let note = copyTarget, let user = currentUser {
                FaceAuthSheet(user: user) {
                    UIPasteboard.general.string = note.content
                    flash(id: note.id)
                    copyTarget = nil
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func noteRow(_ note: SecureNote) -> some View {
        NavigationLink {
            NoteDetailView(note: note)
        } label: {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "note.text")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Brief "copied" badge
                    if flashCopied == note.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .background(Color.green, in: Circle())
                            .offset(x: 4, y: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.25), value: flashCopied)

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.body)
                    Text(notePreview(note.content))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 2)
        }
        // ── Trailing swipe: Copy Content (requires face auth) ──
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                copyTarget   = note
                showCopyAuth = true
            } label: {
                Label("Copy Content", systemImage: "doc.on.doc")
            }
            .tint(.orange)
        }
    }

    // MARK: - Helpers

    /// First 60 characters of content as a safe preview.
    private func notePreview(_ content: String) -> String {
        let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "No content" }
        let limit = clean.index(clean.startIndex, offsetBy: min(60, clean.count))
        return clean.count > 60 ? String(clean[..<limit]) + "…" : clean
    }

    /// Briefly shows the green ✓ badge on the copied row, then clears it.
    private func flash(id: UUID) {
        withAnimation { flashCopied = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { if flashCopied == id { flashCopied = nil } }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.orange.opacity(0.7))
            VStack(spacing: 6) {
                Text("No Secure Notes Yet")
                    .font(.title3.bold())
                Text("Tap + to add your first note.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button { showAddSheet = true } label: {
                Label("Add Note", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 240)
        }
        .padding(32)
        .sheet(isPresented: $showAddSheet) {
            AddEditNoteView(userId: userId)
                .environmentObject(noteStore)
        }
    }
}
