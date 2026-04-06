//
//  NoteStore.swift
//  iOSFaceRecognition
//
//  Secure Note 的 CRUD ViewModel，持久化到 Keychain（JSON + AES-256 加密）。
//  架构完全平行于 PasswordStore，支持相同的软删除 / 30 天自动清理逻辑。
//

import Foundation
import Combine

@MainActor
final class NoteStore: ObservableObject {

    @Published private(set) var entries: [SecureNote] = []

    private let key = "secure_notes_v1"

    init() { load() }

    // MARK: - 查询（仅返回未删除条目）

    /// 指定用户的活跃备忘录，收藏优先，其余按 title 字母排序
    func notes(for userId: String) -> [SecureNote] {
        entries
            .filter { $0.userId == userId && $0.deletedAt == nil }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    /// 搜索过滤（title / content 包含关键字，仅活跃条目）
    func notes(for userId: String, query: String) -> [SecureNote] {
        let all = notes(for: userId)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query)
        }
    }

    /// 最近 30 天内被软删除的条目，按删除时间降序
    func deletedNotes(for userId: String) -> [SecureNote] {
        entries
            .filter { $0.userId == userId && $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    // MARK: - 计数（供主页卡片使用）

    func totalCount(for userId: String) -> Int {
        notes(for: userId).count
    }

    func deletedCount(for userId: String) -> Int {
        deletedNotes(for: userId).count
    }

    // MARK: - 写入

    func add(_ note: SecureNote) {
        entries.append(note)
        persist()
    }

    func update(_ note: SecureNote) {
        guard let idx = entries.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
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

    /// 删除某用户的全部备忘录（注销账号时调用）
    func deleteAll(for userId: String) {
        entries.removeAll { $0.userId == userId }
        persist()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = KeychainHelper.load(account: key) else { return }
        var loaded = (try? JSONDecoder().decode([SecureNote].self, from: data)) ?? []
        // 自动 purge 超过 30 天的软删除条目
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        loaded.removeAll { note in
            guard let d = note.deletedAt else { return false }
            return d < cutoff
        }
        entries = loaded
    }

    private func persist() {
        let data = (try? JSONEncoder().encode(entries)) ?? Data()
        KeychainHelper.save(data, account: key)
    }
}
