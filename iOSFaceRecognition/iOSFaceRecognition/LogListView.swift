//
//  LogListView.swift
//  iOSFaceRecognition
//
//  Access log list — color-coded rows by event type, CSV export.
//

import SwiftUI

struct LogListView: View {
    @EnvironmentObject var logStore: LogStore
    @State private var showClearAlert = false
    @State private var showExportSheet = false
    @State private var csvText = ""

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm:ss"
        return f
    }()

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
                        AppCard {
                            ForEach(Array(logStore.logs.enumerated()), id: \.element.id) { idx, log in
                                VStack(spacing: 0) {
                                    LogRowView(log: log, dateFormatter: dateFormatter)
                                    if idx < logStore.logs.count - 1 {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .navigationTitle("Access Logs (\(logStore.logs.count))")
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
