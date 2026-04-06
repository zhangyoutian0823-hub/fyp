//
//  KeychainHelper.swift
//  iOSFaceRecognition
//
//  轻量 Keychain 封装，接口与 UserDefaults 对齐：
//    save(_:account:)   → 新增或更新
//    load(account:)     → 读取（返回 Data?）
//    delete(account:)   → 删除
//  service 固定为 Bundle Identifier，隔离不同 app 的数据。
//

import Foundation
import Security

enum KeychainHelper {

    private static let service: String =
        Bundle.main.bundleIdentifier ?? "com.facevault.app"

    // MARK: - Save (insert or update)

    @discardableResult
    static func save(_ data: Data, account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        // 尝试更新已有条目
        let attributes: [CFString: Any] = [kSecValueData: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // 不存在则新增
            var addQuery = query
            addQuery[kSecValueData] = data
            // 仅在设备解锁后可读；不同步到 iCloud
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    // MARK: - Load

    static func load(account: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Delete

    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
