//
//  AdminInviteService.swift
//  iOSFaceRecognition
//
//  管理员邀请码服务。
//  负责生成、验证、消费邀请码，并将所有码持久化至 UserDefaults。
//
//  邀请码规则：
//  - 8位字母数字混合（大写 + 数字）
//  - 有效期：24小时
//  - 单次使用：消费后立即标记为已用
//

import Foundation

final class AdminInviteService {

    static let shared = AdminInviteService()
    private init() {}

    private let key = "admin_invite_codes_v1"
    private let charset = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")  // 去掉易混淆字符 I O 1 0

    // MARK: - Generate

    /// 生成新邀请码并持久化存储
    @discardableResult
    func generate(by adminId: String) -> AdminInviteCode {
        let code = (0..<8).map { _ in String(charset.randomElement()!) }.joined()
        let invite = AdminInviteCode(code: code, createdByAdminId: adminId)
        var all = allCodes()
        all.append(invite)
        persist(all)
        return invite
    }

    // MARK: - Validate

    /// 检查邀请码是否有效（存在 + 未使用 + 未过期）
    func validate(_ code: String) -> Bool {
        let upper = code.uppercased()
        return allCodes().first(where: { $0.code == upper })?.isValid == true
    }

    // MARK: - Consume

    /// 标记邀请码为已使用（注册成功后调用）
    func consume(_ code: String) {
        let upper = code.uppercased()
        var all = allCodes()
        guard let idx = all.firstIndex(where: { $0.code == upper }) else { return }
        all[idx].isUsed = true
        all[idx].usedAt = Date()
        persist(all)
    }

    // MARK: - Query

    /// 获取所有邀请码（包含已用/已过期）
    func allCodes() -> [AdminInviteCode] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AdminInviteCode].self, from: data)) ?? []
    }

    /// 获取当前有效的邀请码列表
    func validCodes() -> [AdminInviteCode] {
        allCodes().filter { $0.isValid }
    }

    /// 清理所有已过期或已使用的旧码（释放存储空间）
    func cleanExpired() {
        let cleaned = allCodes().filter { !$0.isExpired && !$0.isUsed }
        persist(cleaned)
    }

    // MARK: - Persistence

    private func persist(_ codes: [AdminInviteCode]) {
        let data = (try? JSONEncoder().encode(codes)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }
}
