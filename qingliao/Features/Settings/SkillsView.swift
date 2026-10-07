// 2026-10-07：技能管理页（对标 Muse 技能页设计）
// 后端 /api/agent/skills

import SwiftUI

struct SkillItem: Identifiable, Decodable {
    let id: String
    let name: String
    let description: String?
    var enabled: Bool
    let category: String?
    let authorized: Bool?
}

struct SkillsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var skills: [SkillItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var notice: String?
    @State private var busySkillIDs = Set<String>()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏：返回 + 添加
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                Spacer()
                Menu {
                    Button {
                        requestSkillPrompt(createSkillPrompt)
                    } label: {
                        Label("创建你的技能", systemImage: "square.and.pencil")
                    }
                    Button {
                        requestSkillPrompt(communitySkillPrompt)
                    } label: {
                        Label("安装社区技能", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 标题区（对标 Muse）
                    Text("技能")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    Text("给你的助理提供特定领域知识和工作流")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    if loading {
                        ProgressView("加载中…")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text(error)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            Button("重试") { Task { await load() } }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else if skills.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("暂无技能")
                                .font(.system(size: 17, weight: .medium))
                            Text("技能给 AI 提供领域知识和工作流")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // 技能列表（对标 Muse 行样式，点行切换启用/禁用）
                        VStack(spacing: 0) {
                            ForEach(skills) { skill in
                                Button {
                                    Task { await toggleSkill(skill) }
                                } label: {
                                    skillRow(skill)
                                }
                                .buttonStyle(.plain)
                                .disabled(busySkillIDs.contains(skill.id))
                                if skill.id != skills.last?.id {
                                    Divider()
                                        .padding(.leading, 68)
                                }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let notice {
                    Text(notice)
                        .font(.system(size: 13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // Muse 式技能行：图标｜名称｜描述｜官方/未授权（点行进详情）
    private func skillRow(_ skill: SkillItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // 图标：installer/creator 用紫色拼图，其他用蓝色文档（对标 Muse）
            let isTool = skill.name.contains("installer") || skill.name.contains("creator")
            Image(systemName: isTool ? "puzzlepiece.extension.fill" : "doc.fill")
                .font(.system(size: 20))
                .foregroundStyle(isTool ? .purple : .blue)
                .frame(width: 48, height: 48)
                .background((isTool ? Color.purple : Color.blue).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.system(size: 17, weight: .semibold))

                if let desc = skill.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }

                // 底部标签行：官方 ｜ 未授权（对标 Muse，无按钮）
                HStack(spacing: 8) {
                    Text(skill.category == "mine" ? "我的" : "官方")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    if skill.authorized == false {
                        Text("未授权")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
            Image(systemName: skill.enabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(skill.enabled ? Color.green : Color.secondary)
                .accessibilityLabel(skill.enabled ? "Hermes 已启用" : "Hermes 已停用")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let j = try await auth.json("/api/agent/skills", method: "GET")
            guard let list = j["skills"] as? [[String: Any]] else {
                throw NSError(domain: "HermesSkills", code: 1,
                              userInfo: [NSLocalizedDescriptionKey:
                                j["error"] as? String ?? "Hermes 未返回技能列表"])
            }
            let data = try JSONSerialization.data(withJSONObject: list)
            skills = try JSONDecoder().decode([SkillItem].self, from: data)
        } catch {
            self.error = "Hermes 技能读取失败：\(error.localizedDescription)"
        }
    }

    private func setEnabled(_ enabled: Bool, for skill: SkillItem) async {
        guard !busySkillIDs.contains(skill.id), skill.enabled != enabled else { return }
        let previous = skill.enabled
        busySkillIDs.insert(skill.id)
        notice = nil
        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[index].enabled = enabled
        }
        defer { busySkillIDs.remove(skill.id) }
        do {
            let result = try await auth.json("/api/agent/skills", method: "POST",
                                             body: ["skill_id": skill.id, "enabled": enabled])
            guard (result["ok"] as? Bool) == true else {
                if (result["saved"] as? Bool) == true {
                    notice = result["error"] as? String ?? "配置已保存，但 Hermes 重启未完成"
                    return
                }
                throw NSError(domain: "HermesSkills", code: 2,
                              userInfo: [NSLocalizedDescriptionKey:
                                result["error"] as? String ?? "Hermes 未接受技能设置"])
            }
            notice = enabled ? "已在 Hermes 启用技能" : "已在 Hermes 停用技能"
        } catch {
            if let index = skills.firstIndex(where: { $0.id == skill.id }) {
                skills[index].enabled = previous
            }
            notice = "设置未生效：\(error.localizedDescription)"
        }
    }

    // 2026-10-07：写闭环 —— 切换技能启用/禁用
    private func toggleSkill(_ skill: SkillItem) async {
        await setEnabled(!skill.enabled, for: skill)
    }

    private let createSkillPrompt = "请帮我创建一个 Hermes 技能。先问清技能名称、解决的问题、触发条件、需要调用的工具、输入输出格式和安全边界；然后给我看完整 SKILL.md 草稿，确认后再写入 Hermes 的 skills 目录，并检查技能能否被识别。不要只告诉我步骤，也不要在我确认前覆盖已有技能。"

    private let communitySkillPrompt = "请帮我安装一个 Hermes 社区技能。先根据我的需求搜索社区仓库，核实来源、最近维护时间、安装内容和所需权限；把候选名称、仓库链接、风险点和安装方式列给我。等我选定后再安装到 Hermes skills 目录，最后刷新技能列表并验证是否启用。不要安装来源不明或要求暴露密钥的技能。"

    private func requestSkillPrompt(_ prompt: String) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            NotificationCenter.default.post(name: .qingliaoOpenChatWithDraft, object: prompt)
        }
    }
}
