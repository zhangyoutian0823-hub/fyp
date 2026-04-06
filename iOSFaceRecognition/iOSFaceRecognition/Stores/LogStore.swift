//
//  LogStore.swift
//  iOSFaceRecognition
//
//  管理访问日志的 ViewModel，持久化到 UserDefaults（JSON）。
//

import Foundation
import Combine

@MainActor
final class LogStore: ObservableObject {

    @Published private(set) var logs: [AccessLog] = []

    private let key = "access_logs_v1"
    private let maxLogs = 500   // 最多保留 500 条日志

    init() { load() }

    // MARK: - 写入日志

    func add(userId: String,
             eventType: AccessEventType,
             similarityScore: Float? = nil,
             detail: String? = nil) {
        let log = AccessLog(userId: userId,
                            eventType: eventType,
                            similarityScore: similarityScore,
                            detail: detail)
        logs.insert(log, at: 0)   // 最新的在最前
        if logs.count > maxLogs { logs = Array(logs.prefix(maxLogs)) }
        persist()
    }

    // MARK: - 查询

    func logs(for userId: String) -> [AccessLog] {
        logs.filter { $0.userId == userId }
    }

    func successLogs() -> [AccessLog] {
        logs.filter { $0.eventType.isSuccess }
    }

    func failedLogs() -> [AccessLog] {
        logs.filter { !$0.eventType.isSuccess }
    }

    // MARK: - 清除

    func clearAll() {
        logs = []
        persist()
    }

    // MARK: - CSV 导出

    func exportCSV() -> String {
        var csv = "Time,UserID,Event,Similarity,Device\n"
        let fmt = ISO8601DateFormatter()
        for log in logs {
            let time  = fmt.string(from: log.timestamp)
            let score = log.similarityScore.map { String(format: "%.2f", $0) } ?? "-"
            csv += "\(time),\(log.userId),\(log.eventType.rawValue),\(score),\(log.deviceName)\n"
        }
        return csv
    }

    // MARK: - 持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        logs = (try? JSONDecoder().decode([AccessLog].self, from: data)) ?? []
    }

    private func persist() {
        let data = (try? JSONEncoder().encode(logs)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }
}
