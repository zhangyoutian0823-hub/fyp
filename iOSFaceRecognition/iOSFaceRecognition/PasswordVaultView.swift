//
//  PasswordVaultView.swift
//  iOSFaceRecognition
//
//  密码库主界面：
//  - 顶部搜索栏
//  - 收藏夹置顶区
//  - 按首字母分组的全部条目列表
//  - 空态引导
//  - 右上角"+"添加新密码
//

import SwiftUI

struct PasswordVaultView: View {
    @EnvironmentObject var passwordStore: PasswordStore
    @EnvironmentObject var session: SessionStore

    @State private var searchText  = ""
    @State private var showAddSheet = false

    // 当前用户 ID
    private var userId: String {
        session.currentUserId ?? ""
    }

    // 搜索过滤后的条目
    private var filtered: [PasswordEntry] {
        passwordStore.entries(for: userId, query: searchText)
    }

    // 收藏条目（搜索过滤后）
    private var favorites: [PasswordEntry] {
        filtered.filter { $0.isFavorite }
    }

    // 非收藏按首字母分组
    private var grouped: [(letter: String, entries: [PasswordEntry])] {
        let nonFav = filtered.filter { !$0.isFavorite }
        let dict = Dictionary(grouping: nonFav) { $0.firstLetter }
        return dict.keys.sorted().map { key in
            (letter: key, entries: dict[key]!)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    List {
                        // ── 收藏夹 ──
                        if !favorites.isEmpty {
                            Section("Favourites") {
                                ForEach(favorites) { entry in
                                    entryRow(entry)
                                }
                            }
                        }

                        // ── 全部（按字母分组）──
                        if !grouped.isEmpty {
                            ForEach(grouped, id: \.letter) { group in
                                Section(group.letter) {
                                    ForEach(group.entries) { entry in
                                        entryRow(entry)
                                    }
                                }
                            }
                        }

                        // ── 搜索无结果 ──
                        if filtered.isEmpty && !searchText.isEmpty {
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
            .navigationTitle("Passwords")
            .searchable(text: $searchText, prompt: "Search passwords")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEditPasswordView(userId: userId)
                    .environmentObject(passwordStore)
            }
        }
    }

    // MARK: - Entry Row

    @ViewBuilder
    private func entryRow(_ entry: PasswordEntry) -> some View {
        NavigationLink {
            PasswordDetailView(entry: entry)
        } label: {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: entry.symbolName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(entry.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 2)
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
                Text("Tap the + button to add your first password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddSheet = true
            } label: {
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
