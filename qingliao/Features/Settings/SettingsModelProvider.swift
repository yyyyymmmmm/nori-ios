// 本文件原为 Features/Settings/SettingsModels.swift 的物理拆分（纯搬运，UI 与行为零改动）。
// 上游文件（SettingsModels.swift）保留 provider 缓存 / 自定义模型组（J 线 2026-10-06：ModelSheet 已删，模型切换并入「连接设置」）；本文件承载 自定义 provider 编辑表 + 关于页。

import Foundation
import SwiftUI

// K 线 2026-10-06：CustomProviderEditSheet 已删（无挂载无调用的旧自定义模型供应商表单）。

// MARK: - 关于Nori（软件介绍页）

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var auth   // v3.0.8：拉 Hermes 版本
    // v3.0.8：Hermes 容器版本（项目版本说明，从 NAS /api/nas/status 实时读）
    @State private var hermesVersion = "读取中…"
    // v4.0.14：Nori后端版本（从免鉴权 /api/version 读，装完 App 一眼确认后端配套哪版）
    @State private var backendVersion = "读取中…"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image("AboutLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        Text("Nori").font(.system(size: 28, weight: .bold))
                        Text("自托管 AI 助手客户端")
                            .font(.system(size: 15)).foregroundStyle(.secondary)
                        Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")")
                            .font(.system(size: 13)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                    GraySettingsGroup(title: "产品") {
                        GraySettingsStaticRow(icon: "sparkles", title: "Nori", subtitle: "SwiftUI 原生客户端，连接自托管 Hermes Agent")
                        MuseRowDivider()
                        GraySettingsStaticRow(icon: "cpu", title: "模型与智能体", subtitle: "由 Hermes 管理模型、技能、记忆与任务")
                        MuseRowDivider()
                        GraySettingsStaticRow(icon: "externaldrive", title: "数据与服务", subtitle: "Nori 后端提供代理与设备连接能力")
                    }

                    GraySettingsGroup(title: "服务版本") {
                        GraySettingsStaticRow(icon: "app", title: "Nori iOS", subtitle: "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")")
                        MuseRowDivider()
                        GraySettingsStaticRow(icon: "sparkle.magnifyingglass", title: "Hermes Agent", subtitle: hermesVersion)
                        MuseRowDivider()
                        GraySettingsStaticRow(icon: "server.rack", title: "Nori 后端", subtitle: backendVersion)
                    }

                    Text("Nous Research · Hermes Agent")
                        .font(.system(size: 13)).foregroundStyle(.tertiary)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("关于 Nori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        // v3.0.8：拉取 Hermes 容器版本（v3.9.28 云端模式移除后不再需要分支）
        .task {
            if let j = try? await auth.json("/api/nas/status"),
               let svc = j["services"] as? [String: Any],
               let v = svc["hermes_version"] as? String, !v.isEmpty {
                hermesVersion = v
            } else {
                hermesVersion = "未获取到"
            }
            // v4.0.14：拉Nori后端版本。/api/version 免鉴权，返回
            // {"version":"v4.0.13","commit":"8f2e181","built":"2026-10-01"}。
            // version 为空 = 部署方没注入版本信息（很常见），此时只显示 commit 或提示，
            // 不算错误 —— 所以不写死"未获取到"当错误态。
            if let j = try? await auth.json("/api/version") {
                let ver = (j["version"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                let commit = (j["commit"] as? String) ?? ""
                let built = (j["built"] as? String) ?? ""
                var parts: [String] = []
                if !ver.isEmpty { parts.append(ver) }
                if !commit.isEmpty { parts.append("(\(commit))") }
                if !built.isEmpty { parts.append("· \(built)") }
                backendVersion = parts.isEmpty ? "未标注版本" : parts.joined(separator: " ")
            } else {
                backendVersion = "未获取到"
            }
        }
    }

}
