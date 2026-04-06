//
//  AllWiFiView.swift
//  iOSFaceRecognition
//
//  WiFi 网络列表：收藏置顶 + 按首字母分组，支持搜索。
//  networkName（SSID）可见；密码需人脸验证才能复制。
//

import SwiftUI

struct AllWiFiView: View {
    @EnvironmentObject var wifiStore: WiFiStore
    @EnvironmentObject var session:   SessionStore
    @EnvironmentObject var userStore: UserStore

    @State private var searchText    = ""
    @State private var showAddSheet  = false

    // Quick-copy via swipe
    @State private var copyTarget:   WiFiEntry? = nil
    @State private var showCopyAuth: Bool       = false
    @State private var flashCopied:  UUID?      = nil

    private var userId: String { session.currentUserId ?? "" }
    private var currentUser: AppUser? { userStore.findUser(userId: userId) }

    // 搜索过滤后的活跃条目
    private var filtered: [WiFiEntry] {
        wifiStore.entries(for: userId, query: searchText)
    }

    // 收藏
    private var favorites: [WiFiEntry] {
        filtered.filter { $0.isFavorite }
    }

    // 非收藏按首字母分组
    private var grouped: [(letter: String, entries: [WiFiEntry])] {
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
                            ForEach(favorites) { wifiRow($0) }
                        }
                    }

                    // ── 按字母分组 ──
                    ForEach(grouped, id: \.letter) { group in
                        Section(group.letter) {
                            ForEach(group.entries) { wifiRow($0) }
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
        .navigationTitle("WiFi Networks")
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
            AddEditWiFiView(userId: userId)
                .environmentObject(wifiStore)
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
    private func wifiRow(_ entry: WiFiEntry) -> some View {
        NavigationLink {
            WiFiDetailView(entry: entry)
        } label: {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "wifi")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.teal.gradient)
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
                    Text(entry.networkName)
                        .font(.body)
                    // 安全类型 badge
                    Text(entry.securityType.rawValue)
                        .font(.caption)
                        .foregroundStyle(securityColor(entry.securityType))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(securityColor(entry.securityType).opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .padding(.vertical, 2)
        }
        // ── Trailing swipe: Copy Password (face auth required) ──
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                if entry.securityType == .open {
                    // Open 网络无密码，直接提示
                    UIPasteboard.general.string = ""
                    flash(id: entry.id)
                } else {
                    copyTarget   = entry
                    showCopyAuth = true
                }
            } label: {
                Label("Copy Password", systemImage: "wifi")
            }
            .tint(.teal)
        }
        // ── Leading swipe: Copy Network Name (no auth) ──
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

    // MARK: - Helpers

    private func securityColor(_ type: WiFiSecurity) -> Color {
        switch type {
        case .wpa3: return .green
        case .wpa2: return .blue
        case .wpa:  return .indigo
        case .wep:  return .orange
        case .open: return .red
        }
    }

    private func flash(id: UUID) {
        withAnimation { flashCopied = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { if flashCopied == id { flashCopied = nil } }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.teal.opacity(0.7))
            VStack(spacing: 6) {
                Text("No WiFi Networks Yet")
                    .font(.title3.bold())
                Text("Tap + to save your first WiFi password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button { showAddSheet = true } label: {
                Label("Add Network", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 240)
        }
        .padding(32)
        .sheet(isPresented: $showAddSheet) {
            AddEditWiFiView(userId: userId)
                .environmentObject(wifiStore)
        }
    }
}
