import SwiftUI

// MARK: - 灰度重做 2026-10-06 晚（C 路）：目标 tab = Muse「目标」页
//
// 对标 Muse 目标页：大标题「目标」+「追踪」分组（绿点 + 绿色文字，语义色保留）
// + 圆形 checkbox 目标行（分割线分隔）+「＋ 创建目标」+ 类别行（点 + 发给 AI）。
// 数据源：GoalStore.shared（保持不动，只换 UI）。

private struct GoalCategory: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
}

struct GoalsTabView: View {
    /// 发给 AI 的唯一出口（DockTabView.askAI：切聊天页 + 0.35s 闸 + post）
    let onAskAI: (String) -> Void
    /// 数据源与 GoalsSection 同一份（GoalStore.shared），只换 UI
    @State private var store = GoalStore.shared

    private let categories: [GoalCategory] = [
        GoalCategory(icon: "heart", name: "健康"),
        GoalCategory(icon: "person.2", name: "人际关系"),
        GoalCategory(icon: "dollarsign", name: "财务"),
        GoalCategory(icon: "briefcase", name: "事业"),
        GoalCategory(icon: "paintpalette", name: "兴趣"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("目标")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 12)

                    // 追踪分组（绿点 + 绿色「追踪」：语义色，保留）
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("追踪")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                    if store.goals.isEmpty {
                        Text("还没有目标，从下面的类别开始，或直接告诉 AI。")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(store.goals) { g in
                                goalRow(g)
                            }
                        }
                    }

                    // ＋ 创建目标
                    Button {
                        onAskAI("我想创建一个新的长期目标，请帮我规划")
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                            Text("创建目标")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 22)

                    Text("选择一个类别，告诉我你想要的目标，我将为你量身定制一个计划，并随着你的成长不断改进。")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        ForEach(categories) { c in
                            categoryRow(c)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, Spacing.section)
                .padding(.bottom, 100)   // 给悬浮 tab bar 留空
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await store.loadFromServer() }
        }
    }

    // MARK: 目标行：checkbox + 标题 + 描述 + …

    private func goalRow(_ g: GoalItem) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleFinished(g)
                } label: {
                    Image(systemName: g.isFinished ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26))
                        .foregroundStyle(g.isFinished ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
                .accessibilityLabel(g.isFinished ? "标为未完成" : "标为已完成")

                VStack(alignment: .leading, spacing: 6) {
                    Text(g.title)
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                    let d = goalDesc(g)
                    if !d.isEmpty {
                        Text(d)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Menu {
                    Button(g.paused ? "恢复每日推进" : "暂停每日推进") {
                        let now = !g.paused
                        store.mutate(g.id) { $0.paused = now }
                        Task { await store.setPausedOnBackend(goalID: g.id, paused: now) }
                        Haptics.success()
                    }
                    Button("删除", role: .destructive) {
                        store.remove(g.id)
                        Task { await store.deleteOnBackend(goalID: g.id) }
                        Haptics.success()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(.vertical, 14)
            Divider()
        }
    }

    /// 行描述：最近一次推进汇报 → 下一步 → 空（不编内容）
    private func goalDesc(_ g: GoalItem) -> String {
        if !g.lastReport.isEmpty { return g.lastReport }
        if let s = g.nextStep { return "下一步：" + s.title }
        return ""
    }

    /// checkbox：全部步骤勾完 = 完成；反之取消完成（同步待办桥）
    private func toggleFinished(_ g: GoalItem) {
        Haptics.success()
        let done = !g.isFinished
        store.mutate(g.id) { item in
            for i in item.steps.indices { item.steps[i].done = done }
            item.finishedAt = done ? Date() : nil
        }
        if let updated = store.goals.first(where: { $0.id == g.id }) {
            for s in updated.steps {
                GoalTodoBridge.syncStepDone(step: s, goal: updated)
            }
        }
    }

    // MARK: 类别行：点 + → 发给 AI

    private func categoryRow(_ c: GoalCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: c.icon)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 30)
            Text(c.name)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Button {
                onAskAI("我想创建一个\(c.name)方面的目标，请帮我量身定制一个计划")
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("创建\(c.name)目标")
        }
        .padding(.vertical, 12)
    }
}
