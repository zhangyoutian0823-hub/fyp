//
//  PasswordEntry.swift
//  iOSFaceRecognition
//
//  密码管理器的核心数据模型。
//  每条记录属于一个登录用户（userId），用户之间完全隔离。
//

import Foundation

struct PasswordEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: String      // 归属用户 ID（对应 AppUser.userId）

    var title: String       // 网站 / App 名称，如 "GitHub"
    var username: String    // 账号 / 邮箱
    var password: String    // 密码明文（存于 UserDefaults JSON，与现有安全级别一致）
    var url: String         // 网址（可选，空字符串表示未填）
    var notes: String       // 备注（可选）
    var isFavorite: Bool    // 是否收藏

    var createdAt: Date
    var updatedAt: Date
    /// 软删除时间戳；nil = 正常，非 nil = 已移入"最近删除"
    var deletedAt: Date?

    // MARK: - 便捷初始化

    init(userId: String,
         title: String,
         username: String,
         password: String,
         url: String = "",
         notes: String = "",
         isFavorite: Bool = false) {
        self.id         = UUID()
        self.userId     = userId
        self.title      = title
        self.username   = username
        self.password   = password
        self.url        = url
        self.notes      = notes
        self.isFavorite = isFavorite
        self.createdAt  = Date()
        self.updatedAt  = Date()
        self.deletedAt  = nil
    }

    /// 距软删除已过多少天（用于 Recently Deleted 展示）
    var daysSinceDeleted: Int? {
        guard let d = deletedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day
    }

    // MARK: - 首字母（列表分组用）

    var firstLetter: String {
        let first = title.trimmingCharacters(in: .whitespaces).uppercased().first
        guard let letter = first, letter.isLetter else { return "#" }
        return String(letter)
    }

    // MARK: - 显示用网站图标名（SF Symbol 降级策略）

    var symbolName: String {
        // 用 title 关键字映射常见图标
        let lower = title.lowercased()
        if lower.contains("github")    { return "chevron.left.forwardslash.chevron.right" }
        if lower.contains("google")    { return "g.circle" }
        if lower.contains("apple")     { return "applelogo" }
        if lower.contains("twitter") || lower.contains("x.com") { return "bird" }
        if lower.contains("facebook")  { return "f.circle" }
        if lower.contains("instagram") { return "camera" }
        if lower.contains("amazon")    { return "cart" }
        if lower.contains("netflix")   { return "play.rectangle" }
        if lower.contains("bank") || lower.contains("pay") { return "creditcard" }
        if lower.contains("mail") || lower.contains("email") { return "envelope" }
        if lower.contains("game")      { return "gamecontroller" }
        return "key.horizontal"        // 默认图标
    }
}
