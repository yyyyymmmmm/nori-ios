// J 线 2026-10-06：对接第三方（消息渠道）。
// 平台清单走 GET /api/hermes/platforms；每行「连接」走 OAuth（POST /api/hermes/oauth/start → auth_url 用 Safari 打开）；
// 后端不通时诚实空态。微信通道模型的老逻辑（/api/channel/*）已下线，微信走此页 platforms 的 weixin 项。

import SwiftUI
import UIKit

struct ThirdPartyView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var platforms: [ThirdPartyPlatform] = []
    @State private var loading = true
    @State private var loadError = false
    @State private var busyID: String? = nil
    @State private var notice: String? = nil
    @State private var configuring: ThirdPartyPlatform?
    @State private var loadErrorText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loadError {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("选择消息平台并填写所需信息。密钥只写入 Hermes 配置，不会回传到 App。")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                            GraySettingsGroup(title: "") {
                                ForEach(platforms) { p in
                                    platformRow(p)
                                    if p.id != platforms.last?.id { MuseRowDivider() }
                                }
                            }
                            .padding(.horizontal, 16)
                            if let notice {
                                Text(notice)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("消息渠道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
            .task { await load() }
            .sheet(item: $configuring) { platform in
                ThirdPartyConfigSheet(platform: platform) { values in
                    await setEnabled(platform, on: true, config: values)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("未能连接到后端")
                .font(.system(size: 17, weight: .medium))
            Text(loadErrorText.isEmpty ? "检查 Nori 后端与 Hermes 容器后重试" : loadErrorText)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            Button("重试") {
                Haptics.tap()
                Task { await load() }
            }
            .font(.system(size: 15, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func platformRow(_ p: ThirdPartyPlatform) -> some View {
        HStack(spacing: 12) {
            platformIcon(p)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                Text(p.enabled ? "已连接" : p.configured ? "已配置 · 未启用" : p.needs == ["qrcode"] ? "需要扫码或配对" : "需要填写连接信息")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            if busyID == p.id {
                ProgressView().controlSize(.small)
            } else if p.enabled {
                Button("断开") {
                    Haptics.tap()
                    Task { _ = await setEnabled(p, on: false) }
                }
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            } else {
                Button(p.configured ? "启用" : p.needs == ["qrcode"] ? "说明" : "设置") {
                    Haptics.tap()
                    if p.needs == ["qrcode"] {
                        notice = "\(p.name) 需要先在 Hermes 网关完成扫码或配对；当前版本暂不支持在 App 内完成。"
                    } else if p.configured {
                        Task { _ = await setEnabled(p, on: true) }
                    } else {
                        configuring = p
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 数据

    /// 图标：有 simple-icons 真实品牌图的用品牌 glyph + 品牌色（已定的品牌色例外），
    /// 找不到品牌图的（钉钉/飞书/企业微信/bluebubbles）与系统通道（email/sms）继续用 SF Symbols 灰度兜底。
    @ViewBuilder
    private func platformIcon(_ p: ThirdPartyPlatform) -> some View {
        if let b = p.brand {
            Image(b.asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(hex: b.hex))
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: p.icon)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
        }
    }

    private func load() async {
        loading = true
        loadError = false
        loadErrorText = ""
        defer { loading = false }
        do {
            let (data, response) = try await auth.request("/api/agent/hermes/platforms")
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            guard (200..<300).contains(response.statusCode),
                  let arr = payload["platforms"] as? [[String: Any]] else {
                loadErrorText = (payload["error"] as? String) ?? "后端返回异常（HTTP \(response.statusCode)）"
                loadError = true
                return
            }
            platforms = arr.compactMap(ThirdPartyPlatform.init(json:))
        } catch {
            loadErrorText = "请求失败：\(error.localizedDescription)"
            loadError = true
        }
    }

    private func setEnabled(_ p: ThirdPartyPlatform, on: Bool, config: [String: String] = [:]) async -> String? {
        busyID = p.id
        defer { busyID = nil }
        do {
            let j = try await auth.json("/api/agent/hermes/platforms", method: "POST",
                                        body: ["platform": p.id, "enabled": on, "config": config])
            guard (j["ok"] as? Bool) == true else {
                notice = (j["error"] as? String) ?? ((j["saved"] as? Bool == true)
                    ? "配置已保存，但 Hermes 重启失败，尚未生效。"
                    : "后端未能保存平台配置。")
                return notice
            }
            notice = nil
            configuring = nil
            await load()
            return nil
        } catch {
            notice = "请求后端失败：\(error.localizedDescription)"
            return notice
        }
    }
}

// MARK: - 模型

struct ThirdPartyPlatform: Identifiable {
    let id: String
    let name: String
    let configured: Bool
    let enabled: Bool
    let needs: [String]

    var icon: String {
        switch id {
        case "weixin":       return "message"
        case "telegram":     return "paperplane"
        case "discord":      return "gamecontroller"
        case "whatsapp":     return "phone"
        case "signal":       return "lock.shield"
        case "slack":        return "number"
        case "email":        return "envelope"
        case "sms":          return "message.fill"
        case "matrix":       return "circle.grid.cross"
        case "mattermost":   return "at"
        case "homeassistant":return "house"
        case "dingtalk":     return "checkmark.seal"
        case "feishu":       return "doc"
        case "wecom":        return "briefcase"
        case "bluebubbles":  return "bubble.left"
        default:             return "app.connected.to.app.below.fill"
        }
    }

    /// 有 simple-icons 真实品牌图的平台 →（asset 名，品牌色 hex）。
    /// hex 取自 simple-icons 数据（develop 分支；slack 取自 v15.0.0，develop 已下架）。
    var brand: (asset: String, hex: String)? {
        switch id {
        case "weixin":        return ("brand_wechat", "07C160")
        case "telegram":      return ("brand_telegram", "26A5E4")
        case "discord":       return ("brand_discord", "5865F2")
        case "whatsapp":      return ("brand_whatsapp", "25D366")
        case "signal":        return ("brand_signal", "3B45FD")
        case "slack":         return ("brand_slack", "4A154B")
        case "matrix":        return ("brand_matrix", "000000")
        case "mattermost":    return ("brand_mattermost", "0058CC")
        case "homeassistant": return ("brand_homeassistant", "18BCF2")
        default:              return nil
        }
    }

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String,
              let name = json["name"] as? String else { return nil }
        self.id = id
        self.name = name
        self.configured = (json["configured"] as? Bool) ?? false
        self.enabled = (json["enabled"] as? Bool) ?? false
        self.needs = json["needs"] as? [String] ?? []
    }
}

private struct ThirdPartyConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    let platform: ThirdPartyPlatform
    let save: ([String: String]) async -> String?
    @State private var values: [String: String] = [:]
    @State private var saving = false
    @State private var errorText: String?

    private var fields: [(String, String)] {
        platform.needs.map { key in
            let title: String
            switch key {
            case "bot_token": title = "Bot Token"
            case "app_token": title = "App Token"
            case "address": title = "邮箱地址"
            case "password": title = "密码 / 授权码"
            case "imap_host": title = "IMAP 服务器"
            case "smtp_host": title = "SMTP 服务器"
            case "account_sid": title = "Account SID"
            case "auth_token": title = "Auth Token"
            case "phone_number": title = "电话号码"
            case "webhook_url": title = "Webhook URL"
            case "homeserver": title = "Homeserver"
            case "user_id": title = "用户 ID"
            case "access_token": title = "Access Token"
            case "server_url": title = "服务地址"
            case "token": title = "访问令牌"
            case "secret": title = "App Secret"
            case "app_id": title = "App ID"
            case "corp_id": title = "Corp ID"
            case "corp_secret": title = "Corp Secret"
            case "url": title = "Webhook URL"
            default: title = key.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return (key, title)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(platform.name, systemImage: "link").font(.headline)
                    Text("连接信息将保存到 Hermes 的平台配置。已有密钥不会显示；重新填写会替换对应字段。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("连接信息") {
                    ForEach(fields, id: \.0) { field in
                        let key = field.0
                        let title = field.1
                        let binding = Binding(get: { values[key, default: ""] }, set: { values[key] = $0 })
                        if key.localizedCaseInsensitiveContains("token") || key.localizedCaseInsensitiveContains("secret") || key == "password" {
                            SecureField(title, text: binding).textInputAutocapitalization(.never).autocorrectionDisabled()
                        } else {
                            TextField(title, text: binding).textInputAutocapitalization(.never).autocorrectionDisabled()
                        }
                    }
                }
            }
            .navigationTitle("配置\(platform.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "保存中" : "保存并连接") {
                        guard !saving else { return }
                        saving = true
                        Task {
                            errorText = await save(values)
                            saving = false
                        }
                    }.disabled(saving || fields.contains(where: { values[$0.0, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.bar)
                }
            }
        }
    }
}

// MARK: - 小工具

private extension Color {
    /// "RRGGBB" / "#RRGGBB"
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var v: UInt64 = 0
        _ = Scanner(string: s).scanHexInt64(&v)
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}
