// 2026-10-07：技能管理页（对标 Muse 技能页设计）
// 后端 /api/agent/skills

import SwiftUI

struct SkillItem: Identifiable, Decodable {
    var id: String { name }
    let name: String
    let description: String?
    let enabled: Bool?
    // 2026-10-07：Muse 式展示字段（后端可选返回）
    let category: String?      // official=官方，mine=我的
    let authorized: Bool?       // 是否已授权

    enum CodingKeys: String, CodingKey {
        case name, description, enabled, category, authorized
    }
}

struct SkillsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var skills: [SkillItem] = []
    @State private var loading = true
    @State private var error: String?

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
                Button {
                    // TODO: 添加技能
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
                                if skill.id != skills.last?.id {
                                    Divider()
                                        .padding(.leading, 68)
                                }
                            }
                        }
                    }
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: 跳转技能详情/授权页
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            if let j = try? await auth.json("/api/agent/skills", method: "GET"),
               let list = j["skills"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: list)
                skills = (try? JSONDecoder().decode([SkillItem].self, from: data)) ?? []
            } else {
                self.error = "加载失败，请检查连接"
            }
        } catch {
            self.error = "加载失败，请检查连接"
        }
    }

    // 2026-10-07：写闭环 —— 切换技能启用/禁用
    private func toggleSkill(_ skill: SkillItem) async {
        let newEnabled = !(skill.enabled == true)
        if let _ = try? await auth.json("/api/agent/skills", method: "POST",
                                         body: ["skill_id": skill.name, "enabled": newEnabled]) {
            await load()
        }
    }
}
