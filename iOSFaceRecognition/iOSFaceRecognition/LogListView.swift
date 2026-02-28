//
//  LogListView.swift
//  iOSFaceRecognition
//
//  管理员访问日志查看界面，按时间倒序显示所有认证事件。
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
            } else {
                List {
                    ForEach(logStore.logs) { log in
                        LogRowView(log: log, dateFormatter: dateFormatter)
                    }
                }
                .listStyle(.plain)
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
            Image(systemName: log.eventType.icon)
                .foregroundStyle(log.eventType.isSuccess ? .green : .red)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.userId)
                        .font(.subheadline.bold())
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
                            .foregroundStyle(score >= FaceMatchService.shared.threshold ? .green : .red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
