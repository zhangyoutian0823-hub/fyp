//
//  SystemBenchmarkView.swift
//  iOSFaceRecognition
//
//  Admin-only performance evaluation dashboard.
//  Computes recognition accuracy metrics (FRR, success rate, similarity
//  distributions) from the existing access log data.
//

import SwiftUI
import Charts

struct SystemBenchmarkView: View {
    @EnvironmentObject var logStore: LogStore
    @EnvironmentObject var userStore: UserStore

    // MARK: - Computed metrics

    private var allLogs: [AccessLog] { logStore.logs }

    // ── Face auth ──
    private var faceTotalAttempts: Int {
        allLogs.filter {
            [.loginSuccess, .loginFailed, .faceMatchFailed, .noFaceDetected, .userNotFound]
                .contains($0.eventType)
        }.count
    }
    private var faceSuccesses: Int {
        allLogs.filter { $0.eventType == .loginSuccess }.count
    }
    private var faceFailures: Int { faceTotalAttempts - faceSuccesses }

    // ── Password auth ──
    private var pwTotalAttempts: Int {
        allLogs.filter {
            $0.eventType == .passwordLoginSuccess || $0.eventType == .passwordLoginFailed
        }.count
    }
    private var pwSuccesses: Int {
        allLogs.filter { $0.eventType == .passwordLoginSuccess }.count
    }

    // ── Overall ──
    private var totalAttempts: Int { faceTotalAttempts + pwTotalAttempts }
    private var totalSuccesses: Int { faceSuccesses + pwSuccesses }
    private var overallSuccessRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalSuccesses) / Double(totalAttempts) * 100
    }

    // ── FRR (False Rejection Rate) — genuine users incorrectly rejected ──
    private var frr: Double {
        guard faceTotalAttempts > 0 else { return 0 }
        return Double(faceFailures) / Double(faceTotalAttempts) * 100
    }

    // ── Similarity stats ──
    private var successScores: [Float] {
        allLogs.filter { $0.eventType == .loginSuccess }
               .compactMap { $0.similarityScore }
    }
    private var failScores: [Float] {
        allLogs.filter { $0.eventType == .faceMatchFailed }
               .compactMap { $0.similarityScore }
    }
    private var avgSuccessSim: Double {
        guard !successScores.isEmpty else { return 0 }
        return Double(successScores.reduce(0, +)) / Double(successScores.count) * 100
    }
    private var avgFailSim: Double {
        guard !failScores.isEmpty else { return 0 }
        return Double(failScores.reduce(0, +)) / Double(failScores.count) * 100
    }

    // ── Per-user stats ──
    private struct UserStat: Identifiable {
        let id: String
        let name: String
        let attempts: Int
        let successes: Int
        let avgSim: Double
        var successRate: Double { attempts > 0 ? Double(successes) / Double(attempts) * 100 : 0 }
    }

    private var userStats: [UserStat] {
        userStore.users.map { user in
            let logs = logStore.logs(for: user.userId)
            let face = logs.filter {
                [.loginSuccess, .loginFailed, .faceMatchFailed, .noFaceDetected, .userNotFound]
                    .contains($0.eventType)
            }
            let succ = face.filter { $0.eventType == .loginSuccess }
            let scores = succ.compactMap { $0.similarityScore }
            let avg = scores.isEmpty ? 0.0
                : Double(scores.reduce(0, +)) / Double(scores.count) * 100
            return UserStat(
                id: user.userId, name: user.name,
                attempts: face.count, successes: succ.count, avgSim: avg
            )
        }.sorted { $0.attempts > $1.attempts }
    }

    // ── Similarity histogram data (20 bins 0-100%) ──
    private struct SimBin: Identifiable {
        let id: Int
        let label: String
        let successCount: Int
        let failCount: Int
    }

    private var simHistogram: [SimBin] {
        let bins = 10
        var sucBins = [Int](repeating: 0, count: bins)
        var failBins = [Int](repeating: 0, count: bins)
        for s in successScores {
            let idx = min(Int(s * Float(bins)), bins - 1)
            sucBins[idx] += 1
        }
        for s in failScores {
            let idx = min(Int(s * Float(bins)), bins - 1)
            failBins[idx] += 1
        }
        return (0..<bins).map { i in
            SimBin(id: i,
                   label: "\(i * 10)%",
                   successCount: sucBins[i],
                   failCount: failBins[i])
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ── Summary cards ──
                summarySection

                // ── Similarity distribution chart ──
                if !successScores.isEmpty || !failScores.isEmpty {
                    similarityChartSection
                }

                // ── Per-user table ──
                if !userStats.isEmpty {
                    userStatsSection
                }

                // ── Methodology note ──
                methodologyNote

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("System Benchmark")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary Section

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Overview", icon: "chart.bar.xaxis")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(
                    title: "Total Attempts",
                    value: "\(totalAttempts)",
                    icon: "list.bullet.clipboard",
                    color: .blue
                )
                metricCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", overallSuccessRate),
                    icon: "checkmark.shield",
                    color: totalSuccesses > 0 ? .green : .secondary
                )
                metricCard(
                    title: "Face FRR",
                    value: faceTotalAttempts > 0
                        ? String(format: "%.1f%%", frr)
                        : "N/A",
                    icon: "person.fill.xmark",
                    color: frr < 10 ? .green : (frr < 25 ? .orange : .red),
                    subtitle: "False Rejection Rate"
                )
                metricCard(
                    title: "Avg Sim (✓)",
                    value: successScores.isEmpty
                        ? "N/A"
                        : String(format: "%.1f%%", avgSuccessSim),
                    icon: "waveform.path.ecg",
                    color: .indigo,
                    subtitle: "Successful logins"
                )
            }

            // Secondary row
            HStack(spacing: 12) {
                miniStatCard(label: "Face Auth",
                             value: "\(faceSuccesses)/\(faceTotalAttempts)",
                             color: .blue)
                miniStatCard(label: "Password Auth",
                             value: "\(pwSuccesses)/\(pwTotalAttempts)",
                             color: .purple)
                miniStatCard(label: "Avg Sim (✗)",
                             value: failScores.isEmpty ? "N/A"
                                 : String(format: "%.1f%%", avgFailSim),
                             color: .red)
            }
        }
    }

    // MARK: - Similarity Distribution Chart

    @ViewBuilder
    private var similarityChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("Similarity Distribution", icon: "chart.bar.fill")
                Spacer()
                HStack(spacing: 10) {
                    legendDot(color: .green,  label: "Success")
                    legendDot(color: .red,    label: "Fail")
                }
            }

            // Stacked bar histogram
            Chart {
                ForEach(simHistogram) { bin in
                    BarMark(x: .value("Sim", bin.label),
                            y: .value("Count", bin.successCount))
                    .foregroundStyle(Color.green.opacity(0.70))
                    .cornerRadius(3, style: .continuous)

                    BarMark(x: .value("Sim", bin.label),
                            y: .value("Count", bin.failCount))
                    .foregroundStyle(Color.red.opacity(0.65))
                    .cornerRadius(3, style: .continuous)
                }
                // Threshold line
                RuleMark(x: .value("Threshold",
                                   String(format: "%.0f%%",
                                          AppSettings.faceThreshold * 100)))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.orange)
                .annotation(position: .top) {
                    Text("Threshold")
                        .font(.caption2).foregroundStyle(.orange)
                }
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel().font(.caption2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Per-User Table

    @ViewBuilder
    private var userStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Per-User Accuracy", icon: "person.2.fill")

            AppCard {
                ForEach(Array(userStats.enumerated()), id: \.element.id) { idx, stat in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            // Avatar initial
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Text(String(stat.name.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stat.name)
                                    .font(.subheadline.bold())
                                Text("ID: \(stat.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(stat.attempts > 0
                                     ? String(format: "%.0f%%", stat.successRate)
                                     : "N/A")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(rateColor(stat.successRate,
                                                               hasData: stat.attempts > 0))
                                Text("\(stat.successes)/\(stat.attempts) ✓")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            // Avg similarity pill
                            if stat.avgSim > 0 {
                                Text(String(format: "%.0f%%", stat.avgSim))
                                    .font(.caption.bold())
                                    .foregroundStyle(.indigo)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.indigo.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        if idx < userStats.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Methodology Note

    @ViewBuilder
    private var methodologyNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Measurement Notes")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                noteRow("FRR", "Calculated from genuine user rejections ÷ face attempts.")
                noteRow("FAR", "Cannot be derived from production logs alone. Requires controlled impostor test data.")
                noteRow("EER", "Equal Error Rate requires plotting FAR vs FRR curves across multiple thresholds — use the Settings page to vary threshold.")
                noteRow("Similarity", "Cosine similarity of L2-normalised 128D Vision embeddings.")
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func noteRow(_ term: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("• \(term):")
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .frame(width: 36, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Reusable sub-views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.footnote.bold())
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }

    private func metricCard(title: String, value: String, icon: String,
                            color: Color, subtitle: String? = nil) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            VStack(spacing: 1) {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func miniStatCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color.opacity(0.75)).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func rateColor(_ rate: Double, hasData: Bool) -> Color {
        guard hasData else { return .secondary }
        if rate >= 80 { return .green }
        if rate >= 60 { return .orange }
        return .red
    }
}

