// v4.4.x：连接中心——Hermes / Home Assistant 等服务配置（"零 SSH"原则）。
// 后端 /api/connections 读状态，/api/connections/homeassistant 写配置，
// /api/connections/homeassistant/test 测连通性。密钥永不回传、永不落盘。

import SwiftUI

// MARK: - 数据模型

struct ConnectionInfo: Decodable, Identifiable {
    var id: String
    var name: String
    var configured: Bool
    var url: String?
    var editable: Bool
    var note: String?
}

// MARK: - 状态点

struct ConnStatusDot: View {
    let configured: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(configured ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(configured ? "已配置" : "未配置")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Home Assistant 详情页

struct HomeAssistantDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var auth

    @State private var baseURL = ""
    @State private var token = ""
    @State private var configured = false
    @State private var testing = false
    @State private var saving = false
    @State private var message = ""
    @State private var messageOK = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 说明
                    Text("填入 Home Assistant 的地址和长期访问令牌，配置后 Nori 可以查询设备状态、执行智能家居控制。")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // 状态卡
                    GraySettingsGroup(title: "") {
                        HStack {
                            Text("状态")
                                .font(.system(size: 17))
                            Spacer()
                            ConnStatusDot(configured: configured)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)

                    // 配置卡
                    GraySettingsGroup(title: "") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("服务地址")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("http://homeassistant.local:8123", text: $baseURL)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)

                            Text("长期访问令牌")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                            SecureField("粘贴长期访问令牌", text: $token)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            Text("在 Home Assistant「个人资料 → 长期访问令牌」中创建")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .padding(.horizontal, 16)

                    // 消息
                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundStyle(messageOK ? .green : .red)
                            .padding(.horizontal, 20)
                    }

                    // 按钮
                    VStack(spacing: 12) {
                        OnboardingPrimaryButton(
                            title: testing ? "测试中…" : "测试连接",
                            enabled: !testing && !saving
                                && !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            Task { await testConnection() }
                        }
                        Button(saving ? "保存中…" : "保存") {
                            Task { await saveConfig() }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(uiColor: .systemGray6))
                        )
                        .disabled(saving || testing
                            || baseURL.trimmingCharacters(in: .whitespaces).isEmpty
                            || token.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Home Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                await loadStatus()
            }
        }
    }

    @MainActor
    private func loadStatus() async {
        guard !loaded else { return }
        loaded = true
        do {
            let (data, _) = try await auth.request(
                "/api/connections", method: "GET")
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = obj["connections"] as? [[String: Any]],
               let ha = list.first(where: { ($0["id"] as? String) == "homeassistant" }) {
                configured = (ha["configured"] as? Bool) ?? false
                baseURL = (ha["url"] as? String) ?? ""
            }
        } catch {
            message = "读取状态失败"
            messageOK = false
        }
    }

    @MainActor
    private func testConnection() async {
        testing = true
        message = ""
        defer { testing = false }
        do {
            let (data, _) = try await auth.request(
                "/api/connections/homeassistant/test", method: "POST",
                body: ["base_url": baseURL.trimmingCharacters(in: .whitespaces),
                       "token": token.trimmingCharacters(in: .whitespaces)])
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if (obj["ok"] as? Bool) == true {
                    let ver = (obj["version"] as? String) ?? ""
                    message = ver.isEmpty ? "连接成功" : "连接成功（HA \(ver)）"
                    messageOK = true
                } else {
                    message = (obj["error"] as? String) ?? "连接失败"
                    messageOK = false
                }
            }
        } catch {
            message = "测试失败：网络不通"
            messageOK = false
        }
    }

    @MainActor
    private func saveConfig() async {
        saving = true
        message = ""
        defer { saving = false }
        do {
            let (data, _) = try await auth.request(
                "/api/connections/homeassistant", method: "POST",
                body: ["base_url": baseURL.trimmingCharacters(in: .whitespaces),
                       "token": token.trimmingCharacters(in: .whitespaces)])
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (obj["ok"] as? Bool) == true {
                configured = true
                token = ""
                message = "已保存"
                messageOK = true
            } else {
                message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["error"] as? String } ?? "保存失败"
                messageOK = false
            }
        } catch {
            message = "保存失败：网络不通"
            messageOK = false
        }
    }
}

// MARK: - NAS 存储配置（v4.4.x 新增）

struct NASDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var auth

    @State private var path = ""
    @State private var configured = false
    @State private var saving = false
    @State private var message = ""
    @State private var messageOK = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("设置 NAS 上的文件保存位置。App 发送的附件（PDF/文档等）将保存到该目录。")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    GraySettingsGroup(title: "") {
                        HStack {
                            Text("状态")
                                .font(.system(size: 17))
                            Spacer()
                            ConnStatusDot(configured: configured)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)

                    GraySettingsGroup(title: "") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NAS 路径")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("/vol1/1000/docker/uploads", text: $path)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)

                            Button {
                                Task { await save() }
                            } label: {
                                HStack {
                                    if saving { ProgressView().scaleEffect(0.8) }
                                    Text(saving ? "保存中…" : "保存")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            }
                            .disabled(saving || path.trimmingCharacters(in: .whitespaces).isEmpty)

                            if !message.isEmpty {
                                Text(message)
                                    .font(.system(size: 14))
                                    .foregroundStyle(messageOK ? .green : .red)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("NAS 存储")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                if !loaded {
                    loaded = true
                    await load()
                }
            }
        }
    }

    private func load() async {
        do {
            let (data, _) = try await auth.request("/api/connections", method: "GET")
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = obj["connections"] as? [[String: Any]],
               let nas = list.first(where: { ($0["id"] as? String) == "nas" }) {
                configured = (nas["configured"] as? Bool) ?? false
                path = (nas["url"] as? String) ?? ""
            }
        } catch {}
    }

    private func save() async {
        saving = true
        defer { saving = false }
        message = ""
        do {
            let (data, _) = try await auth.request(
                "/api/connections/nas", method: "POST",
                body: ["path": path.trimmingCharacters(in: .whitespaces)])
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (obj["ok"] as? Bool) == true {
                configured = true
                message = "已保存"
                messageOK = true
            } else {
                message = "保存失败"
                messageOK = false
            }
        } catch {
            message = "保存失败：网络不通"
            messageOK = false
        }
    }
}
