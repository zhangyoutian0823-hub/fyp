//
//  LogListView.swift
//  iOSFaceRecognition
//
//  Access log list — color-coded rows, date & type filter, CSV export.
//

import SwiftUI

// MARK: - Filter Enums

private enum TimeFilter: String, CaseIterable {
    case all   = "All"
    case today = "Today"
    case week  = "This Week"
}

private enum TypeFilter: String, CaseIterable {
    case all     = "All"
    case success = "Success"
    case failed  = "Failed"
}

struct LogListView: View {
    @EnvironmentObject var logStore: LogStore
    @State private var timeFilter: TimeFilter = .all
    @State private var typeFilter: TypeFilter = .all
    @State private var showClearAlert = false
    @State private var showExportSheet = false
    @State private var csvText = ""

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm:ss"
        return f
    }()

    // MARK: - Computed

    private var filteredLogs: [AccessLog] {
        let cal = Calendar.current
        return logStore.logs.filter { log in
            let timeOK: Bool = {
                switch timeFilter {
                case .all:   return true
                case .today: return cal.isDateInToday(log.timestamp)
                case .week:
                    guard let weekAgo = cal.date(byAdding: .day, value: -7, to: Date())
                    else { return true }
                    return log.timestamp >= weekAgo
                }
            }()
            let typeOK: Bool = {
                switch typeFilter {
                case .all:     return true
                case .success: return log.eventType.isSuccess
                case .failed:  return !log.eventType.isSuccess
                }
            }()
            return timeOK && typeOK
        }
    }

    private var isFiltered: Bool { timeFilter != .all || typeFilter != .all }
    private var successCount: Int { filteredLogs.filter { $0.eventType.isSuccess }.count }
    private var failedCount:  Int { filteredLogs.count - successCount }

    var body: some View {
        Group {
            if logStore.logs.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Authentication events will appear here.")
                )
                .background(Color(uiColor: .systemGroupedBackground))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // ── Filter bar ──
                        filterBar
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        // ── Summary chips ──
                        summaryChips
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // ── Log rows or empty state ──
                        if filteredLogs.isEmpty {
                            ContentUnavailableView(
                                "No Matching Logs",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("Try adjusting the filters above.")
                            )
                            .padding(.top, 40)
                        } else {
                            AppCard {
                                ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { idx, log in
                                    VStack(spacing: 0) {
                                        LogRowView(log: log, dateFormatter: dateFormatter)
                                        if idx < filteredLogs.count - 1 {
                                            Divider().padding(.leading, 60)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                        }
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .navigationTitle(isFiltered
            ? "Logs · \(filteredLogs.count)/\(logStore.logs.count)"
            : "Access Logs (\(logStore.logs.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .destructive) {
                    showClearAlert = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(logStore.logs.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    csvText = logStore.exportCSV()
                    showExportSheet = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(logStore.logs.isEmpty)
            }
        }
        .alert("Clear All Logs?", isPresented: $showClearAlert) {
            Button("Clear", role: .destructive) { logStore.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(logStore.logs.count) log entries.")
        }
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(text: csvText)
        }
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private var filterBar: some View {
        VStack(spacing: 8) {
            // Time filter row
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                ForEach(TimeFilter.allCases, id: \.self) { f in
                    filterChip(f.rawValue, selected: timeFilter == f, selectedColor: .blue) {
                        withAnimation(.easeInOut(duration: 0.18)) { timeFilter = f }
                    }
                }
                Spacer()
            }

            // Type filter row
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                ForEach(TypeFilter.allCases, id: \.self) { f in
                    let color: Color = f == .success ? .green : (f == .failed ? .red : .blue)
                    filterChip(f.rawValue, selected: typeFilter == f, selectedColor: color) {
                        withAnimation(.easeInOut(duration: 0.18)) { typeFilter = f }
                    }
                }
                Spacer()
                if isFiltered {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            timeFilter = .all
                            typeFilter = .all
                        }
                    } label: {
                        Label("Reset", systemImage: "xmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func filterChip(
        _ title: String,
        selected: Bool,
        selectedColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected
                    ? selectedColor.opacity(0.15)
                    : Color(uiColor: .tertiarySystemGroupedBackground))
                .foregroundStyle(selected ? selectedColor : .secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? selectedColor.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Summary Chips

    @ViewBuilder
    private var summaryChips: some View {
        HStack(spacing: 8) {
            summaryPill(count: filteredLogs.count, label: "Total",   color: .blue)
            summaryPill(count: successCount,       label: "Success", color: .green)
            summaryPill(count: failedCount,        label: "Failed",  color: .red)
            Spacer()
        }
    }

    private func summaryPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}

// MARK: - Log Row

private struct LogRowView: View {
    let log: AccessLog
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 12) {
            // Colored icon circle
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
                HStack {
                    Text(log.userId)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(dateFormatter.string(from: log.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(log.eventType.rawValue)
                        .font(.caption)
                        .foregroundStyle(log.eventType.isSuccess ? .green : .secondary)
                    if let score = log.similarityScore {
                        Spacer()
                        Text(String(format: "%.1f%%", score * 100))
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(score >= FaceMatchService.shared.threshold
                                        ? Color.green.opacity(0.12)
                                        : Color.red.opacity(0.12))
                            .foregroundStyle(score >= FaceMatchService.shared.threshold ? .green : .red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
