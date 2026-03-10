//
//  PasswordStore.swift
//  iOSFaceRecognition
//
//  密码条目的 CRUD ViewModel，持久化到 UserDefaults（JSON）。
//  与现有 UserStore / LogStore 持久化模式完全一致。
//

import Foundation
import Combine

@MainActor
final class PasswordStore: ObservableObject {

    @Published private(set) var entries: [PasswordEntry] = []

    private let key = "password_entries_v1"

    init() { load() }

    // MARK: - 查询

    /// 返回指定用户的所有条目，收藏优先，其余按 title 字母排序
    func entries(for userId: String) -> [PasswordEntry] {
        entries
            .filter { $0.userId == userId }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    /// 搜索过滤（title 或 username 包含关键字）
    func entries(for userId: String, query: String) -> [PasswordEntry] {
        let all = entries(for: userId)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query) ||
            $0.url.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - 写入

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

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func toggleFavorite(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].isFavorite.toggle()
        entries[idx].updatedAt = Date()
        persist()
    }

    /// 删除某用户的全部密码条目（用户账号注销时调用）
    func deleteAll(for userId: String) {
        entries.removeAll { $0.userId == userId }
        persist()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        entries = (try? JSONDecoder().decode([PasswordEntry].self, from: data)) ?? []
    }

    private func persist() {
        let data = (try? JSONEncoder().encode(entries)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }
}
