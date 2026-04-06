//
//  WiFiStore.swift
//  iOSFaceRecognition
//
//  WiFi 条目的 CRUD ViewModel，持久化到 Keychain（JSON + AES-256 加密）。
//  架构完全平行于 PasswordStore / NoteStore，支持软删除 / 30 天自动清理。
//

import Foundation
import Combine

@MainActor
final class WiFiStore: ObservableObject {

    @Published private(set) var entries: [WiFiEntry] = []

    private let key = "wifi_entries_v1"

    init() { load() }

    // MARK: - 查询（仅返回未删除条目）

    /// 指定用户的活跃条目，收藏优先，其余按 networkName 字母排序
    func entries(for userId: String) -> [WiFiEntry] {
        entries
            .filter { $0.userId == userId && $0.deletedAt == nil }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                return $0.networkName.localizedCaseInsensitiveCompare($1.networkName) == .orderedAscending
            }
    }

    /// 搜索过滤（networkName / notes 包含关键字，仅活跃条目）
    func entries(for userId: String, query: String) -> [WiFiEntry] {
        let all = entries(for: userId)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        return all.filter {
            $0.networkName.localizedCaseInsensitiveContains(query) ||
            $0.notes.localizedCaseInsensitiveContains(query)
        }
    }

    /// 最近 30 天内被软删除的条目，按删除时间降序
    func deletedEntries(for userId: String) -> [WiFiEntry] {
        entries
            .filter { $0.userId == userId && $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    // MARK: - 计数

    func totalCount(for userId: String) -> Int {
        entries(for: userId).count
    }

    func deletedCount(for userId: String) -> Int {
        deletedEntries(for: userId).count
    }

    // MARK: - 写入

    func add(_ entry: WiFiEntry) {
        entries.append(entry)
        persist()
    }

    func update(_ entry: WiFiEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.updatedAt = Date()
        entries[idx] = updated
        persist()
    }

    func toggleFavorite(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].isFavorite.toggle()
        entries[idx].updatedAt = Date()
        persist()
    }

    // MARK: - 软删除 / 恢复 / 永久删除

    func softDelete(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].deletedAt = Date()
        persist()
    }

    func restore(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].deletedAt = nil
        persist()
    }

    func hardDelete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func hardDeleteAllDeleted(for userId: String) {
        entries.removeAll { $0.userId == userId && $0.deletedAt != nil }
        persist()
    }

    /// 删除某用户的全部 WiFi 条目（注销账号时调用）
    func deleteAll(for userId: String) {
        entries.removeAll { $0.userId == userId }
        persist()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = KeychainHelper.load(account: key) else { return }
        var loaded = (try? JSONDecoder().decode([WiFiEntry].self, from: data)) ?? []
        // 自动 purge 超过 30 天的软删除条目
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        loaded.removeAll { entry in
            guard let d = entry.deletedAt else { return false }
            return d < cutoff
        }
        entries = loaded
    }

    private func persist() {
        let data = (try? JSONEncoder().encode(entries)) ?? Data()
        KeychainHelper.save(data, account: key)
    }
}
