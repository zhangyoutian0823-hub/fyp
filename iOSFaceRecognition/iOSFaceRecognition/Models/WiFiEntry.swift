//
//  WiFiEntry.swift
//  iOSFaceRecognition
//
//  WiFi 网络条目模型。
//  networkName（SSID）列表中可见；password 查看时需人脸验证。
//  支持软删除（deletedAt），30 天后自动 purge。
//

import Foundation

// MARK: - WiFiSecurity

enum WiFiSecurity: String, Codable, CaseIterable, Identifiable {
    case wpa3 = "WPA3"
    case wpa2 = "WPA2"
    case wpa  = "WPA"
    case wep  = "WEP"
    case open = "Open"

    var id: String { rawValue }

    /// SF Symbol 图标
    var symbolName: String {
        switch self {
        case .wpa3: return "lock.shield.fill"
        case .wpa2: return "lock.fill"
        case .wpa:  return "lock"
        case .wep:  return "exclamationmark.lock"
        case .open: return "lock.open"
        }
    }
}

// MARK: - WiFiEntry

struct WiFiEntry: Identifiable, Codable {
    let id: UUID
    var userId: String
    var networkName: String      // SSID — 列表可见，无需 face auth
    var password: String         // 敏感字段，查看需 face auth（Open 网络为空）
    var securityType: WiFiSecurity
    var notes: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?         // nil = 活跃；非 nil = 软删除

    // MARK: - Init

    init(
        userId: String,
        networkName: String,
        password: String = "",
        securityType: WiFiSecurity = .wpa2,
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id           = UUID()
        self.userId       = userId
        self.networkName  = networkName
        self.password     = password
        self.securityType = securityType
        self.notes        = notes
        self.isFavorite   = isFavorite
        self.createdAt    = Date()
        self.updatedAt    = Date()
        self.deletedAt    = nil
    }

    // MARK: - Computed

    /// 首字母（供分组用）
    var firstLetter: String {
        networkName.first?.isLetter == true
            ? networkName.prefix(1).uppercased()
            : "#"
    }

    /// 软删除距今天数
    var daysSinceDeleted: Int? {
        guard let d = deletedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day
    }
}
