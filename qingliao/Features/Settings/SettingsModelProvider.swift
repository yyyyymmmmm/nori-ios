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
        VStack(spacing: 14) {
            // v2.0.34：关于页换新图标（淡青底微笑气泡，与 AppIcon 同款）
            Image("AboutLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            Text("Nori")
                .font(.system(size: Typography.titleXL, weight: .bold))
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0")")
                .font(.system(size: Typography.subhead))
                .foregroundStyle(.secondary)

            Divider().padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 10) {
                // v3.0.8：项目版本说明（iOS 客户端版本）
                aboutRow("项目版本", "Nori · iOS 客户端 v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                // v3.0.3：统一介绍框架 —— 云端直连已于 v3.9.28 整体移除，本页只剩本地 AI 一种形态
                aboutRow("产品", "Nori —— 面向家庭的 AI 智能助手，SwiftUI 原生客户端，连接自家 NAS 上的 Hermes Agent，数据本地保存。")
                appModeRow()
                aboutRow("功能", "流式对话 · 语音对话 · 图片理解 · 知识库检索 · 会话同步 · NAS 面板 · Docker 管理 · 智能家居 · 定时任务")
                aboutRow("模型", "DeepSeek V4 / Kimi / StepFun 多模型聚合（OpenCode Go + 官方 API）")
                aboutRow("架构", "SwiftUI 原生 · Hermes Agent · 自建 NAS 后端（连接自家 NAS）")
                // v3.0.8：Hermes Agent 版本号固定放在介绍最后一行（本地模式读容器实时版本）
                HStack(alignment: .top) {
                    Text("Hermes Agent")
                        .font(.system(size: Typography.subhead, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 68, alignment: .leading)
                    Text(hermesVersion)
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.secondary)
                }
                // v4.0.14：Nori后端版本（/api/version 免鉴权，失败只显示"未获取到"，不打扰用户）
                HStack(alignment: .top) {
                    Text("Nori后端")
                        .font(.system(size: Typography.subhead, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 68, alignment: .leading)
                    Text(backendVersion)
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: Typography.subhead))
            .padding(.horizontal, 24)

            Spacer()
            Text("Nous Research · Hermes Agent")
                .font(.system(size: Typography.caption))
                .foregroundStyle(.tertiary)
                .padding(.bottom, Spacing.xl)
        }
        .padding(.top, 22)
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

    /// v3.0.3：当前模式行（v3.9.28 云端直连移除后恒为本地 AI）
    private func appModeRow() -> some View {
        aboutRow("当前模式", "本地 AI —— 连接自家 NAS 上的 Hermes Agent，对话/读图/语音/知识库/智能家居全掌控。")
    }

    private func aboutRow(_ title: String, _ content: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: Typography.subhead, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(content)
                .font(.system(size: Typography.subhead))
                .foregroundStyle(.primary)
        }
    }
}
