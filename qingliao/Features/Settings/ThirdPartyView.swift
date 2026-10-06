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
                            Text("点按连接，跳转厂商授权页同意即可，全程不用填地址和密钥。")
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
            .navigationTitle("对接第三方")
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
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("未能连接到后端")
                .font(.system(size: 17, weight: .medium))
            Text("检查 Hermes 连接后重试")
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
            Image(systemName: p.icon)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                Text(p.enabled ? "已连接" : "未连接")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            if busyID == p.id {
                ProgressView().controlSize(.small)
            } else if p.enabled {
                Button("断开") {
                    Haptics.tap()
                    Task { await setEnabled(p, on: false) }
                }
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            } else {
                Button("连接") {
                    Haptics.tap()
                    Task { await connect(p) }
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

    private func load() async {
        loading = true
        loadError = false
        defer { loading = false }
        guard let j = try? await auth.json("/api/hermes/platforms"),
              let arr = j["platforms"] as? [[String: Any]] else {
            loadError = true
            return
        }
        platforms = arr.compactMap(ThirdPartyPlatform.init(json:))
    }

    /// 连接：优先走 OAuth（点按授权零填写）；无 OAuth 的平台走启用开关。
    private func connect(_ p: ThirdPartyPlatform) async {
        busyID = p.id
        defer { busyID = nil }
        // 先试 OAuth
        if let j = try? await auth.json("/api/hermes/oauth/start", method: "POST",
                                        body: ["vendor_id": p.id]),
           let url = j["auth_url"] as? String, !url.isEmpty,
           let u = URL(string: url) {
            await MainActor.run { UIApplication.shared.open(u) }
            notice = "已在浏览器打开授权页，完成授权后下拉…返回此页即自动刷新"
            return
        }
        // 无 OAuth：直接启用
        await setEnabled(p, on: true)
    }

    private func setEnabled(_ p: ThirdPartyPlatform, on: Bool) async {
        busyID = p.id
        defer { busyID = nil }
        // 先试 OAuth 断开（云厂商），再走平台开关
        if !on {
            _ = try? await auth.json("/api/hermes/oauth/disconnect", method: "POST",
                                     body: ["vendor_id": p.id])
        }
        if let j = try? await auth.json("/api/hermes/platforms", method: "POST",
                                        body: ["platform": p.id, "enabled": on]),
           (j["ok"] as? Bool) == true {
            await load()
        } else {
            notice = on ? "连接失败，请检查后端" : "断开失败，请检查后端"
        }
    }
}

// MARK: - 模型

struct ThirdPartyPlatform: Identifiable {
    let id: String
    let name: String
    let configured: Bool
    let enabled: Bool

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

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String,
              let name = json["name"] as? String else { return nil }
        self.id = id
        self.name = name
        self.configured = (json["configured"] as? Bool) ?? false
        self.enabled = (json["enabled"] as? Bool) ?? false
    }
}
