//
//  FacebindView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/1/26.
//

import SwiftUI

struct FaceBindView: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) var dismiss

    @State private var username: String
    @State private var step: Int = 0

    init(defaultUsername: String) {
        _username = State(initialValue: defaultUsername)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {

                VStack(spacing: 6) {
                    Text("绑定人脸（UI建模）")
                        .font(.title3).bold()
                    Text("后续接入：相机采集 → Vision 检测 → 特征提取 → 存模板")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("绑定到账号")
                        .font(.headline)

                    TextField("用户名（建议先输入）", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    // 采集占位步骤
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                            .frame(height: 240)

                        VStack(spacing: 10) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(stepText)
                                .foregroundStyle(.white.opacity(0.95))
                                .font(.footnote)
                        }
                    }

                    Button {
                        advance()
                    } label: {
                        Label(step < 2 ? "下一步采集" : "完成绑定", systemImage: step < 2 ? "arrow.right" : "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()
            }
            .padding()
            .navigationTitle("绑定人脸")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var stepText: String {
        switch step {
        case 0: return "采集 1/3：正面看镜头（占位）"
        case 1: return "采集 2/3：轻微左转（占位）"
        default: return "采集 3/3：轻微右转（占位）"
        }
    }

    private func advance() {
        if step < 2 {
            step += 1
        } else {
            auth.bindFace(to: username)
            dismiss()
        }
    }
}


#Preview {
    FaceBindView(defaultUsername: "")
        .environmentObject(AuthStore())
}
