// MARK: - Hermes捷径面板 + 快捷指令面板（从 ChatComponents.swift 拆出）
import SwiftUI

// MARK: - v2.0.96 Hermes 捷径面板（官方斜杠命令 + 功能注释，点击填充输入框）

struct HermesShortcutSheet: View {
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    // 官方命令（hermes-agent 文档）：命令 + 中文功能注释
    private let items: [(cmd: String, desc: String)] = [
        ("/help", "查看全部可用命令"),
        ("/new", "开启全新会话（清空上下文）"),
        ("/model deepseek-v4-flash", "切换模型（如 deepseek-v4-flash）"),
        ("/compress", "压缩当前上下文，节省 token"),
        ("/memory", "查看与管理 AI 记忆"),
        ("/skills", "浏览、搜索、安装技能"),
        ("/skill <名称>", "加载指定技能到当前会话"),
        ("/cron", "定时任务管理（查看/创建/暂停）"),
        ("/voice on", "开启语音对话模式"),
        ("/voice off", "关闭语音模式"),
        ("/undo", "撤销上一轮对话"),
        ("/title <名称>", "给当前会话命名"),
        ("/usage", "查看 Token 用量统计"),
        ("/status", "查看会话与系统状态"),
        ("/personality <名称>", "切换 AI 人格"),
        ("/reasoning high", "设置思考深度（none/low/medium/high）"),
        ("/background <任务>", "后台运行长任务（不阻塞对话）"),
        ("/queue <任务>", "排队等待下一轮处理"),
        ("/fast", "切换优先快速处理"),
        ("/resume <名称>", "恢复历史会话"),
        ("/sethome", "把当前聊天设为默认投递位置"),
        ("/update", "更新 Hermes 到最新版"),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(items, id: \.cmd) { item in
                    Button {
                        onPick(item.cmd)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Text(item.cmd)
                                .font(.system(size: Typography.subhead, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                            Text(item.desc)
                                .font(.system(size: Typography.subhead))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
            }
            .navigationTitle("Hermes 捷径")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                }
            }
        }
    }
}

// MARK: - v2.0.43 快捷指令面板（常用 prompt 模板，点击填充输入框）

struct QuickPromptSheet: View {
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var prompts: [(icon: String, name: String, prompt: String)] {
        var list: [(icon: String, name: String, prompt: String)] = [
            ("character.bubble", "翻译", "请将以下内容翻译成英文（保留原意）：\n"),
            ("list.bullet.rectangle", "总结", "请用 3-5 条要点总结以下内容：\n"),
            ("pencil.and.outline", "润色", "请润色以下文字，使其更通顺、专业、简洁：\n"),
            ("doc.text", "写周报", "请根据以下工作内容生成一份结构化周报：\n"),
            ("chevron.left.forwardslash.chevron.right", "写代码", "请实现以下功能，给出完整代码并简要解释：\n"),
            ("curlybraces", "解释代码", "请逐段解释以下代码的作用和逻辑：\n"),
            ("lightbulb", "头脑风暴", "请围绕以下主题给出 5 个有创意的点子：\n"),
            ("checklist", "待办清单", "请把以下内容整理成清晰的待办清单：\n"),
            ("textformat", "取标题", "请为以下内容取 3 个简洁贴切的标题：\n"),
            ("person.2", "角色扮演", "请扮演一个资深嵌入式硬件工程师，回答以下问题：\n"),
        ]
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("快捷指令")
                    .font(.system(size: Typography.title, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Typography.titleXL))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, Spacing.lg)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(prompts, id: \.name) { p in
                        Button {
                            onPick(p.prompt)
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: p.icon)
                                    .font(.system(size: Typography.headline))
                                    .foregroundStyle(Color.accentColor)
                                Text(p.name)
                                    .font(.system(size: Typography.subhead, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.section)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(Tint.faint), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - v3.9.48 输入栏展开态的「模型快选」（右下角胶囊 → 点一下就切走）

/// 和设置里的「模型管理」(`ModelSheet`) 分工：那张面板管**provider 增删 / 同步 / TTS / 视觉模型**，
/// 这里只管"当场换一个模型接着聊"——选完即写即收起。
/// 数据同源 `ModelProvidersCache`（模型管理每次同步成功都会落这份缓存），
/// 所以本面板**零网络请求**、打开就是列表；从没同步过才只剩去设置那一条路。
/// ⚠️ 写的是主模型两把 key（`qingliao_model` / `qingliao_provider`），与 `ModelSheet.setModel` 同一口径；
///    配了 Agent 模型时它不生效（视觉 > Agent > 主），面板顶部照 `ModelSheet` 的话术把这件事说清楚，
///    不静默骗人。
struct ComposerModelSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    // 默认值必须与全站其余读点逐字一致（自查清单第 3 条）
    @AppStorage("qingliao_model") private var modelName = "deepseek-v4-flash"
    @AppStorage("qingliao_provider") private var provider = "opencode"
    @State private var groups: [HermesProviderGroup] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var actionError: String?
    @State private var savingID: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("正在读取 Hermes 模型…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    VStack(spacing: 10) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: Typography.display, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("模型列表加载失败")
                            .font(.system(size: Typography.subhead))
                            .foregroundStyle(.secondary)
                        Text(loadError)
                            .font(.system(size: Typography.tiny))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        Button("重试") { Task { await loadModels() } }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groups.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "cube.box")
                            .font(.system(size: Typography.display, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("Hermes 当前没有可选模型")
                            .font(.system(size: Typography.subhead))
                            .foregroundStyle(.secondary)
                        Button("重新读取") { Task { await loadModels() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text("模型与当前选择均由 Hermes 管理")
                                .font(.system(size: Typography.tiny))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(groups) { group in
                            Section(group.name) {
                                if let error = group.error {
                                    Text(error)
                                        .font(.system(size: Typography.tiny))
                                        .foregroundStyle(.orange)
                                }
                                ForEach(group.models) { model in
                                    modelRow(model, in: group.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("切换模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                }
            }
            .task { await loadModels() }
            .alert("无法切换模型", isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("好", role: .cancel) { actionError = nil }
            } message: {
                Text(actionError ?? "请稍后重试")
            }
        }
    }

    private func loadModels() async {
        loading = true
        loadError = nil
        defer { loading = false }
        do {
            let response = try await auth.json("/api/agent/hermes/inspect/models")
            guard let models = response["models"] as? [[String: Any]] else {
                loadError = (response["error"] as? String) ?? "Hermes 没有返回模型数据"
                groups = []
                return
            }
            var grouped: [String: [[String: Any]]] = [:]
            for model in models {
                let providerID = model["provider"] as? String ?? "hermes"
                grouped[providerID, default: []].append(model)
            }
            groups = grouped.keys.sorted().compactMap { providerID in
                HermesProviderGroup(json: [
                    "id": providerID,
                    "name": providerID,
                    "models": grouped[providerID] ?? []
                ])
            }
        } catch {
            groups = []
            loadError = error.localizedDescription
        }
    }

    private func modelRow(_ model: HermesModelOption, in providerID: String) -> some View {
        Button {
            Task { await select(model, providerID: providerID) }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(providerID)
                        .font(.system(size: Typography.tiny))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if savingID == "\(providerID)|\(model.id)" {
                    ProgressView()
                } else if model.selected || (model.id == modelName && providerID == provider) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(savingID != nil)
        .accessibilityLabel("切换到模型 \(model.name)（\(providerID)）")
    }

    private func select(_ model: HermesModelOption, providerID: String) async {
        guard savingID == nil else { return }
        let key = "\(providerID)|\(model.id)"
        savingID = key
        defer { savingID = nil }
        do {
            let response = try await auth.json("/api/agent/hermes/model", method: "POST",
                                               body: ["provider": providerID, "model_id": model.id])
            guard (response["ok"] as? Bool) == true else {
                actionError = (response["error"] as? String) ?? "Hermes 切换模型失败"
                return
            }
            modelName = model.id
            provider = providerID
            Haptics.success()
            dismiss()
        } catch {
            actionError = "切换失败：\(error.localizedDescription)"
        }
    }
}

