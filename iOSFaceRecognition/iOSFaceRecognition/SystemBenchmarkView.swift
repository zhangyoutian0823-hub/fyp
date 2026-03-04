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

    // ── Impostor / FAR stats ──
    private var impostorScores: [Float] {
        allLogs.filter { $0.eventType == .impostorAttempt }
               .compactMap { $0.similarityScore }
    }
    private var impostorFooledCount: Int {
        impostorScores.filter { $0 >= AppSettings.faceThreshold }.count
    }
    private var trueFAR: Double {
        guard !impostorScores.isEmpty else { return 0 }
        return Double(impostorFooledCount) / Double(impostorScores.count) * 100
    }
    private var avgImpostorSim: Double {
        guard !impostorScores.isEmpty else { return 0 }
        return Double(impostorScores.reduce(0, +)) / Double(impostorScores.count) * 100
    }

    // ── ROC curve data ──
    private struct ROCPoint: Identifiable {
        let id: Double    // threshold value used as stable id
        let far: Double   // False Accept Rate (%) at this threshold
        let frr: Double   // False Rejection Rate (%) at this threshold
        let isCurrent: Bool
    }

    private var rocPoints: [ROCPoint] {
        let genuineScores = successScores + failScores
        let current = Double(AppSettings.faceThreshold)
        return stride(from: 0.55, through: 0.95, by: 0.05).map { t in
            let ft = Float(t)
            let frr: Double = genuineScores.isEmpty ? 0.0
                : Double(genuineScores.filter { $0 < ft }.count) / Double(genuineScores.count) * 100
            let far: Double = impostorScores.isEmpty ? 0.0
                : Double(impostorScores.filter { $0 >= ft }.count) / Double(impostorScores.count) * 100
            return ROCPoint(id: t, far: far, frr: frr, isCurrent: abs(t - current) < 0.001)
        }
    }

    private var hasROCData: Bool {
        !impostorScores.isEmpty && (!successScores.isEmpty || !failScores.isEmpty)
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

                // ── FAR metrics (impostor test results) ──
                farMetricsSection

                // ── ROC curve (requires both genuine and impostor score data) ──
                if hasROCData {
                    rocCurveSection
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

    // MARK: - FAR Metrics Section

    @ViewBuilder
    private var farMetricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("FAR — Impostor Test Results", icon: "person.fill.questionmark")

            if impostorScores.isEmpty {
                // Placeholder when no tests have been run yet
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No impostor tests recorded")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Use the FAR Impostor Test in the Admin Panel to collect real FAR data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricCard(
                        title: "Impostor Tests",
                        value: "\(impostorScores.count)",
                        icon: "person.fill.questionmark",
                        color: .indigo
                    )
                    metricCard(
                        title: "True FAR",
                        value: String(format: "%.1f%%", trueFAR),
                        icon: "exclamationmark.triangle",
                        color: trueFAR == 0 ? .green : (trueFAR < 10 ? .orange : .red),
                        subtitle: "At current threshold"
                    )
                }
                HStack(spacing: 12) {
                    miniStatCard(label: "Fooled System",
                                 value: "\(impostorFooledCount)",
                                 color: impostorFooledCount == 0 ? .green : .red)
                    miniStatCard(label: "Avg Impostor Sim",
                                 value: String(format: "%.1f%%", avgImpostorSim),
                                 color: .purple)
                    miniStatCard(label: "Correctly Rejected",
                                 value: "\(impostorScores.count - impostorFooledCount)",
                                 color: .green)
                }
            }
        }
    }

    // MARK: - ROC Curve Section

    @ViewBuilder
    private var rocCurveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("ROC Curve", icon: "chart.line.uptrend.xyaxis")
                Spacer()
                HStack(spacing: 10) {
                    legendDot(color: .blue,   label: "FRR")
                    legendDot(color: .red,    label: "FAR")
                    legendDot(color: .orange, label: "Current")
                }
            }

            Text("Each point = one threshold (0.55–0.95). Lower-left = better performance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Chart {
                // FRR line
                ForEach(rocPoints) { pt in
                    LineMark(
                        x: .value("Threshold", pt.id),
                        y: .value("FRR (%)", pt.frr)
                    )
                    .foregroundStyle(Color.blue.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(Circle().strokeBorder(lineWidth: 1))
                    .symbolSize(20)
                    .interpolationMethod(.catmullRom)
                }
                // FAR line
                ForEach(rocPoints) { pt in
                    LineMark(
                        x: .value("Threshold", pt.id),
                        y: .value("FAR (%)", pt.far)
                    )
                    .foregroundStyle(Color.red.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(Circle().strokeBorder(lineWidth: 1))
                    .symbolSize(20)
                    .interpolationMethod(.catmullRom)
                }
                // Current threshold vertical marker
                RuleMark(x: .value("Current", Double(AppSettings.faceThreshold)))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(.orange)
                    .annotation(position: .top) {
                        Text("Threshold")
                            .font(.caption2).foregroundStyle(.orange)
                    }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: [0.60, 0.70, 0.80, 0.90]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.0f%%", v * 100)).font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartYAxisLabel("Rate (%)", position: .leading)
            .chartXAxisLabel("Threshold", position: .bottom)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            // EER note
            if let eerThreshold = findEER() {
                HStack(spacing: 6) {
                    Image(systemName: "equal.circle.fill")
                        .foregroundStyle(.orange)
                    Text(String(format: "EER ≈ %.0f%% threshold (FAR ≈ FRR)", eerThreshold * 100))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Find threshold where FAR ≈ FRR (Equal Error Rate).
    private func findEER() -> Double? {
        guard hasROCData else { return nil }
        var minDiff = Double.infinity
        var eerThreshold: Double?
        for pt in rocPoints {
            let diff = abs(pt.far - pt.frr)
            if diff < minDiff {
                minDiff = diff
                eerThreshold = pt.id
            }
        }
        return eerThreshold
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
                noteRow("FAR", "Requires controlled impostor tests (Admin Panel → FAR Impostor Test). FAR = impostor attempts that passed threshold ÷ total impostor attempts.")
                noteRow("ROC", "Plots FAR vs FRR at each threshold (0.55–0.95). Requires both genuine and impostor score data.")
                noteRow("EER", "Equal Error Rate — the threshold where FAR ≈ FRR. Estimated from the ROC curve crossing point.")
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

