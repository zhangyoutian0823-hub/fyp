//
//  Authstore.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/1/26.
//

import Foundation
import Combine

@MainActor
final class AuthStore: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: String? = nil

    @Published var isFaceBound: Bool = false
    @Published var faceBoundUser: String? = nil

    // ✅ 简易用户库：username -> password（先用内存，后续可换 Keychain/数据库/服务器）
    @Published private(set) var users: [String: String] = [:]

        // 你也可以先给一个默认账号方便测试
        // "admin": "123456"

    // ✅ 注册：成功返回 true；失败（已存在/空）返回 false
    func register(username: String, password: String) -> Bool {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !u.isEmpty, !p.isEmpty else { return false }
        guard users[u] == nil else { return false } // 已存在

        users[u] = p
        return true
    }

    // ✅ 登录：必须账号存在且密码匹配
    func loginWithPassword(username: String, password: String) -> Bool {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let stored = users[u], stored == p else { return false }
        currentUser = u
        isLoggedIn = true
        return true
    }

    func logout() {
        isLoggedIn = false
        currentUser = nil
    }

    func bindFace(to username: String) {
        isFaceBound = true
        faceBoundUser = username
    }

    func loginWithFace(simulatedScore: Double, threshold: Double) -> Bool {
        guard isFaceBound, let u = faceBoundUser else { return false }
        guard simulatedScore >= threshold else { return false }
        currentUser = u
        isLoggedIn = true
        return true
    }
}
