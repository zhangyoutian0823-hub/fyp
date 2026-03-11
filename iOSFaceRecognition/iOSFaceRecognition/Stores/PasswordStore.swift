//
//  PasswordStore.swift
//  iOSFaceRecognition
//
//  密码条目的 CRUD ViewModel，持久化到 UserDefaults（JSON）。
//  支持软删除：条目先移入"最近删除"，30 天后自动清理。
//

import Foundation
import Combine

@MainActor
final class PasswordStore: ObservableObject {

    @Published private(set) var entries: [PasswordEntry] = []

    private let key = "password_entries_v1"

    init() { load() }

    // MARK: - 查询（仅返回未删除条目）

    /// 指定用户的活跃条目，收藏优先，其余按 title 字母排序
    func entries(for userId: String) -> [PasswordEntry] {
        entries
            .filter { $0.userId == userId && $0.deletedAt == nil }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    /// 搜索过滤（title / username / url 包含关键字，仅活跃条目）
    func entries(for userId: String, query: String) -> [PasswordEntry] {
        let all = entries(for: userId)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query) ||
            $0.url.localizedCaseInsensitiveContains(query)
        }
    }

    /// 最近 30 天内被软删除的条目，按删除时间降序
    func deletedEntries(for userId: String) -> [PasswordEntry] {
        entries
            .filter { $0.userId == userId && $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    // MARK: - 活跃条目数 / 问题数（供主页卡片使用）

    func totalCount(for userId: String) -> Int {
        entries(for: userId).count
    }

    func deletedCount(for userId: String) -> Int {
        deletedEntries(for: userId).count
    }

    // MARK: - 写入（活跃条目）

    func add(_ entry: PasswordEntry) {
        entries.append(entry)
        persist()
    }

    func update(_ entry: PasswordEntry) {
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

    /// 软删除：移入"最近删除"（30 天内可恢复）
    func softDelete(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].deletedAt = Date()
        persist()
    }

    /// 恢复：从"最近删除"恢复为活跃条目
    func restore(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].deletedAt = nil
        persist()
    }

    /// 永久删除：从存储中彻底移除
    func hardDelete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    /// 永久删除指定用户全部已软删除条目
    func hardDeleteAllDeleted(for userId: String) {
        entries.removeAll { $0.userId == userId && $0.deletedAt != nil }
        persist()
    }

    /// 删除某用户的全部条目（注销账号时调用，含软删除）
    func deleteAll(for userId: String) {
        entries.removeAll { $0.userId == userId }
        persist()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        var loaded = (try? JSONDecoder().decode([PasswordEntry].self, from: data)) ?? []
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
        UserDefaults.standard.set(data, forKey: key)
    }
}
