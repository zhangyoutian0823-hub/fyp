//
//  ContentView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/1/26.
//

import SwiftUI

enum FaceState: String {
    case idle = "未开始"
    case scanning = "识别中…"
    case success = "识别成功"
    case failed = "识别失败"

    var icon: String {
        switch self {
        case .idle: return "faceid"
        case .scanning: return "viewfinder"
        case .success: return "checkmark.seal.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    var hint: String {
        switch self {
        case .idle: return "点击「开始识别」进行模拟识别流程。"
        case .scanning: return "正在检测人脸并比对特征…"
        case .success: return "匹配成功：允许进入下一步操作（登录/开门等）。"
        case .failed: return "匹配失败：请调整光线/角度，或重新注册。"
        }
    }
}

struct ContentView: View {
    @State private var state: FaceState = .idle

    @State private var matchScore: Double = 0.72
    @State private var threshold: Double = 0.75

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {

                // 顶部状态条（已去掉相机开关）
                HStack(spacing: 12) {
                    Image(systemName: state.icon)
                        .font(.system(size: 28, weight: .semibold))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前状态：\(state.rawValue)")
                            .font(.headline)
                        Text("相机预览：UI占位（未接入真实相机）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // 相机预览区域（占位）
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 360)

                    VStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("相机预览区域（占位）")
                            .foregroundStyle(.white.opacity(0.95))
                        Text("后续接入 AVCaptureVideoPreviewLayer / Vision")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // 取景框装饰
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                        .frame(width: 240, height: 300)
                }

                // 识别结果卡片
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("识别结果")
                            .font(.headline)
                        Spacer()
                        Text("score \(matchScore, specifier: "%.2f") / th \(threshold, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: matchScore, total: 1.0)

                    Text(state.hint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // 按钮区
                HStack(spacing: 12) {
                    Button {
                        startRecognition()
                    } label: {
                        Label("开始识别", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        enrollFace()
                    } label: {
                        Label("注册人脸", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                // 阈值设置
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("阈值设置")
                            .font(.headline)
                        Spacer()
                        Text("\(threshold, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $threshold, in: 0.5...0.95, step: 0.01)
                    Text("阈值越高越严格（更安全但更容易失败）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer(minLength: 6)
            }
            .padding()
            .navigationTitle("人脸识别系统")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - UI Mock Actions

    private func startRecognition() {
        state = .scanning

        // 模拟 1 秒后返回结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            matchScore = Double.random(in: 0.55...0.95)
            state = (matchScore >= threshold) ? .success : .failed
        }
    }

    private func enrollFace() {
        // 这里先占位：后续你可以 push 到注册页，或弹 sheet
        state = .idle
    }
}

#Preview {
    ContentView()
}
