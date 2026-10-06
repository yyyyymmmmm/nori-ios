// 本文件由 2026-09-27 工程治理「Settings 物理合并」生成：多份同域设置页文件合并为一，
// UI 入口与行为零改动，仅文件边界变化。合并前各文件的来源见下方 MARK 分段。

import Combine
import Foundation
import LocalAuthentication
import PDFKit
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: ===== 以下原为 Features/Settings/SettingsModelSheets.swift =====

// MARK: - 设置：模型管理相关 Sheet（v3.0.80 自 SettingsView.swift 拆出，纯搬家无逻辑改动）
// 内容：provider 缓存 / 自定义模型组
// （J 线 2026-10-06：ModelSheet 模型管理页已删 —— 模型切换并入「连接设置」页内下拉；
//  视觉模型 / 微信通道模型 / Agent 模型独立页一并删除，统一走 Hermes 后端）


// MARK: - v3.0.35 provider 模型列表缓存（微信通道 / Agent / 模型管理共用同一份）
//
// 问题背景：WechatChannelSheet / AgentModelSheet 每次打开都从后端拉
// /api/stream/model-providers，失败时 try? 静默吞错 → 列表永远显示"正在加载模型列表…"。
// 方案：成功拉取结果写入 UserDefaults，打开时先显示缓存（免转圈），后台刷新成功后替换。

enum ModelProvidersCache {
    static let key = "qingliao_providers_cache"

    /// 读取缓存（无缓存或解析失败返回空）
    static func load() -> [(id: String, models: [String])] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { d in
            guard let id = d["id"] as? String else { return nil }
            return (id, (d["models"] as? [String]) ?? [])
        }
    }

    /// 写缓存（空列表不覆盖旧缓存——防止后端临时故障把缓存刷空）
    static func save(_ providers: [(id: String, models: [String])]) {
        guard !providers.isEmpty else { return }
        let arr: [[String: Any]] = providers.map { ["id": $0.id, "models": $0.models] }
        if let data = try? JSONSerialization.data(withJSONObject: arr) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - v3.0.74 自定义 provider 模型组（用户自主添加 BASE_URL/API Key，后端 custom_providers.json 存储，免更新 App）
struct CustomProviderItem: Identifiable, Hashable {
    let id: String
    let name: String
    let baseURL: String
    let models: [String]
}

// MARK: - 模型管理（复刻 PWA/OpenCode Go 面板：分组 + 设为当前 + 同步列表）

