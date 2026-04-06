//
//  UserActivityView.swift
//  iOSFaceRecognition
//
//  用户个人登录历史 — 最近 20 条认证记录。
//

import SwiftUI

struct UserActivityView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var logStore: LogStore

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()

    private var myLogs: [AccessLog] {
        guard let uid = session.currentUserId else { return [] }
        return Array(logStore.logs(for: uid)
            .filter {
                $0.eventType != .accountPasswordChanged &&
                $0.eventType != .vaultItemEdited   && $0.eventType != .vaultItemDeleted &&
                $0.eventType != .wifiItemEdited    && $0.eventType != .wifiItemDeleted  &&
                $0.eventType != .noteItemEdited    && $0.eventType != .noteItemDeleted
            }
            .prefix(20))
    }

    private var passwordChangeLogs: [AccessLog] {
        guard let uid = session.currentUserId else { return [] }
        return logStore.logs(for: uid).filter {
            $0.eventType == .accountPasswordChanged ||
            $0.eventType == .vaultItemEdited   || $0.eventType == .vaultItemDeleted ||
            $0.eventType == .wifiItemEdited    || $0.eventType == .wifiItemDeleted  ||
            $0.eventType == .noteItemEdited    || $0.eventType == .noteItemDeleted
        }
    }

    var body: some View {
        Group {
            if myLogs.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your login history will appear here.")
                )
                .background(Color(uiColor: .systemGroupedBackground))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Summary bar
                        HStack(spacing: 16) {
                            summaryBadge(
                                label: "Total",
                                value: "\(myLogs.count)",
                                icon: "list.bullet",
                                color: .blue
                            )
                            summaryBadge(
                                label: "Success",
                                value: "\(myLogs.filter { $0.eventType.isSuccess }.count)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            summaryBadge(
                                label: "Failed",
                                value: "\(myLogs.filter { !$0.eventType.isSuccess }.count)",
                                icon: "xmark.circle.fill",
                                color: .red
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        // ── Login History ──
                        if !myLogs.isEmpty {
                            AppCard {
                                ForEach(Array(myLogs.enumerated()), id: \.element.id) { idx, log in
                                    VStack(spacing: 0) {
                                        activityRow(log: log)
                                        if idx < myLogs.count - 1 {
                                            Divider().padding(.leading, 60)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // ── Password Changes ──
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password Changes")
                                .font(.footnote.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)
                                .padding(.top, 18)

                            if passwordChangeLogs.isEmpty {
                                AppCard {
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.slash")
                                            .font(.system(size: 22))
                                            .foregroundStyle(.secondary)
                                        Text("No password changes recorded")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .padding(.horizontal, 16)
                            } else {
                                AppCard {
                                    ForEach(Array(passwordChangeLogs.enumerated()), id: \.element.id) { idx, log in
                                        VStack(spacing: 0) {
                                            passwordChangeRow(log: log)
                                            if idx < passwordChangeLogs.count - 1 {
                                                Divider().padding(.leading, 60)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .navigationTitle("Login History")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Row

    private func activityRow(log: AccessLog) -> some View {
        HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(log.eventType.isSuccess
                          ? Color.green.opacity(0.15)
                          : Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: log.eventType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(log.eventType.isSuccess ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(log.eventType.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(dateFormatter.string(from: log.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let score = log.similarityScore {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", score * 100))
                            .font(.caption.bold())
                            .foregroundStyle(score >= FaceMatchService.shared.threshold ? .green : .red)
                    }
                }
            }

            Spacer()

            // Success / fail indicator
            Image(systemName: log.eventType.isSuccess ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 16))
                .foregroundStyle(log.eventType.isSuccess ? .green : .red.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Password Change Row

    private func passwordChangeRow(log: AccessLog) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(changeEventColor(log.eventType).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: log.eventType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(changeEventColor(log.eventType))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(log.detail ?? log.eventType.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(dateFormatter.string(from: log.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(log.deviceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Change Event Color

    private func changeEventColor(_ type: AccessEventType) -> Color {
        switch type {
        case .accountPasswordChanged:          return .orange
        case .vaultItemEdited:                 return .blue
        case .vaultItemDeleted:                return .red
        case .wifiItemEdited:                  return .teal
        case .wifiItemDeleted:                 return .red
        case .noteItemEdited:                  return .orange
        case .noteItemDeleted:                 return .red
        default:                               return .blue
        }
    }

    // MARK: - Summary Badge

    private func summaryBadge(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
