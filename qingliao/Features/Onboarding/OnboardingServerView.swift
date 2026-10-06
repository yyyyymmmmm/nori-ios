// MARK: - 引导 ② 连接服务器
//
// 流程：自动扫局域网 → 点卡片一键填入 / 手填地址 → 即时测通 →
// 账号密码登录（复用 AuthStore.login，不另写一套）。
// 登录成功即 onDone（RootView 仍停在引导内，继续走后几屏）。

import SwiftUI

struct OnboardingServerView: View {
    @Environment(AuthStore.self) private var auth
    var onDone: () -> Void = {}

    @State private var scanner = LANScanner()
    @State private var address = ""
    @State private var username = "qingliao"
    @State private var password = ""
    @State private var testing = false
    @State private var testOK = false
    @State private var testMessage: String?
    @State private var loggingIn = false
    @FocusState private var focused: Bool

    /// 测通后才露出登录区
    private var canLogin: Bool { testOK && !address.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingTitleBlock(
                    title: "连接到你的\nAI 服务",
                    subtitle: "Nori 跑在你自己的服务上，先连上它。"
                )
                .padding(.top, 18)

                // 扫描状态行
                HStack(spacing: 10) {
                    if scanner.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(scanner.isScanning ? "正在扫描局域网…" : (scanner.servers.isEmpty ? "局域网里没找到，可手动输入" : "在局域网找到以下服务"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !scanner.isScanning && scanner.servers.isEmpty {
                        Button("重新扫描") {
                            Task { await scanner.scan() }
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                }
                .padding(.top, 22)

                if let err = scanner.scanError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                // 发现的服务器卡片
                ForEach(scanner.servers) { s in
                    Button {
                        address = s.urlString
                        testOK = false
                        testMessage = nil
                    } {
                        HStack(spacing: 14) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                                .frame(width: 48, height: 48)
                                .background(Color(uiColor: .systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.displayTitle)
                                    .font(.system(size: 14.5, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(s.displaySubtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("可连接")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(uiColor: .systemGray5))
                                .clipShape(Capsule())
                        }
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    AuthStore.normalizedServerURL(address) == AuthStore.normalizedServerURL(s.urlString)
                                        ? Color(uiColor: .label) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }

                // 分隔
                HStack(spacing: 12) {
                    Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                    Text("或").font(.system(size: 12)).foregroundStyle(.tertiary)
                    Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                }
                .padding(.vertical, 20)

                Text("手动输入服务地址")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("https://你的地址:端口", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 14.5))
                    .padding(14)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($focused)
                    .padding(.top, 8)
                    .onChange(of: address) { _, _ in
                        testOK = false
                        testMessage = nil
                    }

                // 测试连接
                Button {
                    Task { await runTest() }
                } label: {
                    HStack {
                        if testing { ProgressView().controlSize(.small) }
                        Text(testing ? "测试中…" : "测试连接")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(testing || address.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top, 10)

                if let msg = testMessage {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundStyle(testOK ? .primary : .secondary)
                        .padding(.top, 8)
                }

                // 登录区（测通后露出）
                if canLogin {
                    Text("登录")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                    TextField("账号", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14.5))
                        .padding(14)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.top, 8)
                    SecureField("密码", text: $password)
                        .font(.system(size: 14.5))
                        .padding(14)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.top, 8)

                    if let err = auth.errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                    }
                }

                Spacer(minLength: 24)

                OnboardingPrimaryButton(
                    title: loggingIn ? "登录中…" : "连接并登录",
                    enabled: canLogin && !username.isEmpty && !password.isEmpty && !loggingIn
                ) {
                    Task { await runLogin() }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            // 进屏自动扫一次
            await scanner.scan()
        }
    }

    // MARK: - 动作

    private func runTest() async {
        testing = true
        testMessage = nil
        defer { testing = false }
        let result = await auth.testConnection(server: address)
        // testConnection 返回 emoji 前缀串：✅/⚠️/❌
        testOK = result.hasPrefix("✅")
        // 去掉 emoji 前缀，界面自己表态
        testMessage = result.replacingOccurrences(of: "^[✅⚠️❌]\\s*", with: "", options: .regularExpression)
        if testOK {
            auth.saveServer(address)
        }
    }

    private func runLogin() async {
        loggingIn = true
        defer { loggingIn = false }
        // 登录前确保地址已保存（testConnection 通过时已存，双保险）
        auth.saveServer(address)
        await auth.login(username: username, password: password)
        if auth.isLoggedIn {
            onDone()
        }
    }
}
