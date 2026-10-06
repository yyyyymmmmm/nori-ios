// 2026-10-07：技能管理页（后端 /api/agent/skills）

import SwiftUI

struct SkillItem: Identifiable, Decodable {
    var id: String { name }
    let name: String
    let description: String?
    let enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case name, description, enabled
    }
}

struct SkillsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var skills: [SkillItem] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("加载中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") { Task { await load() } }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if skills.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("暂无技能")
                            .font(.system(size: 17, weight: .medium))
                        Text("技能给 AI 提供领域知识和工作流\n可在 Hermes 侧安装 agentskills.io 标准技能")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(skills) { skill in
                        HStack(spacing: 12) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                                .frame(width: 36, height: 36)
                                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(skill.name)
                                    .font(.system(size: 16, weight: .medium))
                                if let desc = skill.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            if let enabled = skill.enabled {
                                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(enabled ? .green : Color.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("技能")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await load() }
            .refreshable { await load() }
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
                // 兼容直接返回数组的格式
                if let j = try? await auth.json("/api/agent/skills", method: "GET"),
                   let arr = j["data"] as? [[String: Any]] {
                    let data = try JSONSerialization.data(withJSONObject: arr)
                    skills = (try? JSONDecoder().decode([SkillItem].self, from: data)) ?? []
                }
            }
        } catch {
            self.error = "加载失败，请检查连接"
        }
    }
}
