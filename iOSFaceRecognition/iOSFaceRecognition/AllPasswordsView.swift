//
//  AllPasswordsView.swift
//  iOSFaceRecognition
//
//  全部密码列表：收藏置顶 + 按首字母分组，支持搜索。
//  从 PasswordVaultView 主页点击"All"卡片进入。
//

import SwiftUI

struct AllPasswordsView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var session:       SessionStore
    @EnvironmentObject var userStore:     UserStore

    @State private var searchText    = ""
    @State private var showAddSheet  = false

    // Quick-copy via swipe
    @State private var copyTarget:   PasswordEntry? = nil
    @State private var showCopyAuth: Bool           = false
    @State private var flashCopied:  UUID?          = nil  // highlights the just-copied row

    private var userId: String { session.currentUserId ?? "" }

    /// Current AppUser — needed to initialise FaceAuthSheet.
    private var currentUser: AppUser? { userStore.findUser(userId: userId) }

    // 搜索过滤后的活跃条目
    private var filtered: [PasswordEntry] {
        passwordStore.entries(for: userId, query: searchText)
    }

    // 收藏
    private var favorites: [PasswordEntry] {
        filtered.filter { $0.isFavorite }
    }

    // 非收藏按首字母分组
    private var grouped: [(letter: String, entries: [PasswordEntry])] {
        let nonFav = filtered.filter { !$0.isFavorite }
        let dict   = Dictionary(grouping: nonFav) { $0.firstLetter }
        return dict.keys.sorted().map { (letter: $0, entries: dict[$0]!) }
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
                            ForEach(favorites) { entryRow($0) }
                        }
                    }

                    // ── 按字母分组 ──
                    ForEach(grouped, id: \.letter) { group in
                        Section(group.letter) {
                            ForEach(group.entries) { entryRow($0) }
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
        .navigationTitle("All Passwords")
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
            AddEditPasswordView(userId: userId)
                .environmentObject(passwordStore)
        }
        // Face-auth sheet for swipe-to-copy password
        .sheet(isPresented: $showCopyAuth) {
            if let entry = copyTarget, let user = currentUser {
                FaceAuthSheet(user: user) {
                    UIPasteboard.general.string = entry.password
                    flash(id: entry.id)
                    copyTarget = nil
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func entryRow(_ entry: PasswordEntry) -> some View {
        NavigationLink {
            PasswordDetailView(entry: entry)
        } label: {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: entry.symbolName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Brief "copied" badge
                    if flashCopied == entry.id {
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
                    Text(entry.title)
                        .font(.body)
                    Text(entry.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 2)
        }
        // ── Trailing swipe: Copy Password (requires face auth) ──
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                copyTarget   = entry
                showCopyAuth = true
            } label: {
                Label("Copy Password", systemImage: "key.fill")
            }
            .tint(.indigo)
        }
        // ── Leading swipe: Copy Username (no auth — already visible in the list) ──
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

    // MARK: - Helpers

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
            Image(systemName: "key.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.blue.opacity(0.7))
            VStack(spacing: 6) {
                Text("No Passwords Yet")
                    .font(.title3.bold())
                Text("Tap + to add your first password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button { showAddSheet = true } label: {
                Label("Add Password", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 240)
        }
        .padding(32)
        .sheet(isPresented: $showAddSheet) {
            AddEditPasswordView(userId: userId)
                .environmentObject(passwordStore)
        }
    }
}
