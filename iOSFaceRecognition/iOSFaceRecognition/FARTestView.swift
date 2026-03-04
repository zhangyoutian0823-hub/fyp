//
//  FARTestView.swift
//  iOSFaceRecognition
//
//  Admin-only FAR (False Accept Rate) impostor test screen.
//  Select a target account → present a different person's face →
//  system records whether the impostor fooled the threshold.
//  Results feed into the ROC curve on the System Benchmark page.
//

import SwiftUI

struct FARTestView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var logStore: LogStore

    @StateObject private var camera = CameraService()

    // Target user whose stored embedding will be tested against
    @State private var selectedTargetId: String = ""

    // Test state
    @State private var isProcessing = false
    @State private var errorMsg: String?
    @State private var lastResult: TestResult?

    struct TestResult: Identifiable {
        let id = UUID()
        let score: Float
        let fooled: Bool   // true = FAR event (system was fooled)
        let targetName: String
    }

    // Enrolled users (must have face embedding)
    private var enrolledUsers: [AppUser] {
        userStore.users.filter { $0.faceEmbedding != nil }
    }

    // Recent impostor test logs
    private var recentTests: [AccessLog] {
        logStore.logs
            .filter { $0.eventType == .impostorAttempt }
            .prefix(10)
            .map { $0 }
    }

    // Overall stats
    private var totalTests: Int {
        logStore.logs.filter { $0.eventType == .impostorAttempt }.count
    }
    private var fooledCount: Int {
        logStore.logs
            .filter { $0.eventType == .impostorAttempt }
            .compactMap { $0.similarityScore }
            .filter { $0 >= AppSettings.faceThreshold }.count
    }
    private var farPercent: Double {
        guard totalTests > 0 else { return 0 }
        return Double(fooledCount) / Double(totalTests) * 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Explanation banner ──
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How FAR Testing Works")
                            .font(.subheadline.bold())
                        Text("Select a registered account, then let a DIFFERENT person face the camera. The system tests if the impostor can fool the face matcher. Results are saved to the System Benchmark.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(Color.indigo.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.indigo.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // ── Target Account Picker ──
                VStack(alignment: .leading, spacing: 0) {
                    Label("Target Account", systemImage: "person.crop.circle")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 4)

                    AppCard {
                        if enrolledUsers.isEmpty {
                            Text("No users with face enrollment found.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            Picker("Target", selection: $selectedTargetId) {
                                Text("Select a user…").tag("")
                                ForEach(enrolledUsers) { user in
                                    Text("\(user.name) (\(user.userId))").tag(user.userId)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                }

                // ── Camera Section ──
                VStack(alignment: .leading, spacing: 10) {
                    Label("Impostor Camera", systemImage: "camera.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    ZStack {
                        CameraView(service: camera)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        FaceOverlayView(observations: camera.faceObservations)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        ScannerBracketShape()
                            .stroke(
                                camera.faceDetected ? Color.red : Color.white.opacity(0.5),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(height: 260)
                            .animation(.easeInOut(duration: 0.25), value: camera.faceDetected)

                        VStack {
                            HStack {
                                Label(
                                    camera.faceDetected ? "Impostor Face Detected" : "No Face",
                                    systemImage: camera.faceDetected ? "person.fill.questionmark" : "circle.dashed"
                                )
                                .font(.caption.bold())
                                .foregroundStyle(camera.faceDetected ? .red : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.45))
                                .clipShape(Capsule())
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(12)
                    }
                }

                // ── Error Banner ──
                if let errorMsg {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMsg)
                    }
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // ── Processing ──
                if isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Running impostor test…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ── Run Test Button ──
                Button {
                    Task { await runTest() }
                } label: {
                    Label("Run Impostor Test", systemImage: "person.fill.questionmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canTest ? Color.red : Color.red.opacity(0.35))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canTest)

                // ── Latest Result Card ──
                if let result = lastResult {
                    resultCard(result)
                        .transition(.scale.combined(with: .opacity))
                }

                // ── Overall Stats ──
                if totalTests > 0 {
                    statsSection
                }

                // ── Test History ──
                if !recentTests.isEmpty {
                    historySection
                }

                Spacer(minLength: 24)
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("FAR Impostor Test")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            camera.start()
            if selectedTargetId.isEmpty, let first = enrolledUsers.first {
                selectedTargetId = first.userId
            }
        }
        .onDisappear { camera.stop() }
        .animation(.easeInOut(duration: 0.3), value: lastResult?.id)
    }

    // MARK: - Computed

    private var canTest: Bool {
        !selectedTargetId.isEmpty && camera.faceDetected && !isProcessing
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func resultCard(_ result: TestResult) -> some View {
        VStack(spacing: 12) {
            // Icon + verdict
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(result.fooled ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: result.fooled ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(result.fooled ? .red : .green)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.fooled ? "⚠️ System Fooled — FAR Event" : "✅ Correctly Rejected")
                        .font(.subheadline.bold())
                        .foregroundStyle(result.fooled ? .red : .green)
                    Text("Target: \(result.targetName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Similarity badge
                VStack(spacing: 2) {
                    Text(String(format: "%.1f%%", result.score * 100))
                        .font(.title3.bold())
                        .foregroundStyle(result.fooled ? .red : .green)
                    Text("similarity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            // Threshold reference
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "Threshold: %.0f%%  |  %@ by %.1f%%",
                            AppSettings.faceThreshold * 100,
                            result.fooled ? "Passed" : "Rejected",
                            abs(result.score - AppSettings.faceThreshold) * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(result.fooled ? Color.red.opacity(0.35) : Color.green.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cumulative Results", systemImage: "chart.bar")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                miniStat(label: "Tests Run", value: "\(totalTests)", color: .indigo)
                miniStat(label: "Fooled System", value: "\(fooledCount)", color: .red)
                miniStat(label: "True FAR",
                         value: String(format: "%.1f%%", farPercent),
                         color: farPercent == 0 ? .green : (farPercent < 10 ? .orange : .red))
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recent Tests", systemImage: "clock")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            AppCard {
                ForEach(Array(recentTests.enumerated()), id: \.element.id) { idx, log in
                    let passed = (log.similarityScore ?? 0) >= AppSettings.faceThreshold
                    HStack(spacing: 12) {
                        Image(systemName: passed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(passed ? .red : .green)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Target: \(log.userId)")
                                .font(.caption.bold())
                            Text(log.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let score = log.similarityScore {
                            Text(String(format: "%.1f%%", score * 100))
                                .font(.caption.bold())
                                .foregroundStyle(passed ? .red : .green)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if idx < recentTests.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
    }

    private func miniStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
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

    // MARK: - Test Logic

    @MainActor
    private func runTest() async {
        errorMsg = nil
        lastResult = nil

        guard let target = userStore.findUser(userId: selectedTargetId) else {
            errorMsg = "Target user not found."
            return
        }
        guard let storedEmbedding = target.faceEmbedding else {
            errorMsg = "Target user has no face enrollment."
            return
        }
        guard camera.faceDetected else {
            errorMsg = "No face detected. Position the impostor in front of the camera."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        // Capture photo
        camera.capture()
        var waited = 0
        while camera.lastPhoto == nil && waited < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }
        guard let photo = camera.lastPhoto else {
            errorMsg = "Failed to capture photo. Try again."
            return
        }
        camera.lastPhoto = nil  // reset for next test

        // Extract impostor embedding
        guard let impostorEmbedding = await FaceEmbeddingService.shared.extractEmbedding(from: photo) else {
            errorMsg = "Could not extract face features. Ensure good lighting."
            return
        }

        // Compare with target's stored embedding
        let score = FaceMatchService.shared.similarity(impostorEmbedding, storedEmbedding)
        let fooled = score >= AppSettings.faceThreshold

        // Log the result
        logStore.add(userId: target.userId,
                     eventType: .impostorAttempt,
                     similarityScore: score)

        // Show result
        withAnimation {
            lastResult = TestResult(score: score,
                                    fooled: fooled,
                                    targetName: target.name)
        }
    }
}
