//
//  LoginView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/1/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var isRegisterMode: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var threshold: Double = 0.75

    @State private var message: String? = nil
    @State private var showBind: Bool = false
    @State private var isFaceScanning: Bool = false
    @State private var lastFaceScore: Double = 0.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {

                // 标题
                VStack(spacing: 6) {
                    Image(systemName: "faceid")
                        .font(.system(size: 44, weight: .semibold))
                    Text("刷脸登录系统")
                        .font(.title2).bold()
                    Text(auth.isFaceBound ? "已绑定人脸：\(auth.faceBoundUser ?? "-")" : "未绑定人脸")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // 账号密码登录
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(isRegisterMode ? "注册账号" : "账号密码登录")
                            .font(.headline)
                        Spacer()
                        Button(isRegisterMode ? "去登录" : "去注册") {
                            isRegisterMode.toggle()
                            message = nil
                        }
                        .font(.footnote)
                    }

                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("密码", text: $password)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        if isRegisterMode {
                            let ok = auth.register(username: username, password: password)
                            if ok {
                                message = "注册成功，请登录"
                                isRegisterMode = false
                            } else {
                                message = "注册失败：用户名/密码不能为空，或账号已存在"
                            }
                        } else {
                            let ok = auth.loginWithPassword(username: username, password: password)
                            message = ok ? nil : "登录失败：账号不存在或密码错误"
                        }
                    } label: {
                        Label(isRegisterMode ? "注册" : "登录",
                              systemImage: isRegisterMode ? "person.badge.plus" : "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))


                // 刷脸登录
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("刷脸登录")
                            .font(.headline)
                        Spacer()
                        Text("阈值 \(threshold, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $threshold, in: 0.5...0.95, step: 0.01)

                    // 这里先做“相机预览占位”
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                            .frame(height: 180)
                        VStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(isFaceScanning ? "识别中…" : "相机预览占位（后续接入 AVCapture/Vision）")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.9))
                            if lastFaceScore > 0 {
                                Text("score: \(lastFaceScore, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }

                    Button {
                        faceLogin()
                    } label: {
                        Label("刷脸登录", systemImage: "faceid")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!auth.isFaceBound || isFaceScanning)

                    Button {
                        showBind = true
                    } label: {
                        Label("绑定人脸", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let message {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBind) {
                FaceBindView(defaultUsername: username)
            }
        }
    }

    private func faceLogin() {
        guard auth.isFaceBound else {
            message = "请先绑定人脸"
            return
        }

        message = nil
        isFaceScanning = true
        lastFaceScore = 0

        // 模拟 1 秒识别
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isFaceScanning = false
            let score = Double.random(in: 0.55...0.95)
            lastFaceScore = score

            let ok = auth.loginWithFace(simulatedScore: score, threshold: threshold)
            message = ok ? nil : "刷脸失败：分数不够或未绑定（当前 score=\(String(format: "%.2f", score)))"
        }
    }
}


#Preview {
    LoginView()
        .environmentObject(AuthStore())
}

