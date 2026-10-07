import SwiftUI

// MARK: - H 线：目标 tab = Muse「目标」页
//
// 顶部 chrome：左 sidebar / 中 AITopCapsule（F 线组件）/ 右 "…" 玻璃菜单 + 大标题「目标」。
// 「追踪」分组（绿点 + 绿色文字，语义色保留）：目标行（checkbox + 标题 + 副标题 + …菜单）。
// 右上菜单：显示字幕/隐藏副标题（二选一，控制副标题显隐）、优先显示 追踪/目标（二选一，
// 追踪 = 未暂停的排前面，目标 = 按原序）、已完成目标（进独立列表）。
// 「创建目标」：类别行点 + → onFillInput(该类别的详细创建提示词)，填进对话框、用户自己发送。
// 数据源：GoalStore.shared（保持不动，只换 UI）。

struct GoalsTabView: View {
    /// 填进对话页输入框的唯一出口（DockTabView 侧：切聊天页 + 填入输入框，不自动发送）
    let onFillInput: (String) -> Void
    @State private var store = GoalStore.shared
    @State private var showCompleted = false
    /// 副标题（目标描述）显隐
    @AppStorage("qingliao_goals_showSubtitle") private var showSubtitle = true
    /// 优先显示："track" 追踪优先（未暂停在前）/ "goal" 目标原序
    @AppStorage("qingliao_goals_priority") private var priorityRaw = "track"

    private let categories: [(icon: String, name: String, prompt: String)] = [
        ("heart", "健康",
         "我想创建一个健康方面的目标，请帮我量身定制一个计划。先问我三个关键问题：我目前的健康状况和作息如何、我想达成的具体结果是什么（要可衡量，比如减重多少公斤、每周运动几次）、我每周能投入多少时间；然后帮我定一个具体可衡量的目标，拆成每周可执行的步骤，并设置每周一次的复盘提醒。"),
        ("person.2", "人际关系",
         "我想创建一个人际关系方面的目标，请帮我量身定制一个计划。先问我：我想改善的是哪段关系（家人、伴侣、朋友还是同事）、目前的状况和困扰是什么、我理想的关系状态是什么样；然后帮我定一个具体可衡量的目标，拆成每周可执行的小行动，并设置每周一次的复盘提醒。"),
        ("dollarsign", "财务",
         "我想创建一个财务方面的目标，请帮我量身定制一个计划。先问我：我目前的收支和储蓄情况如何、我想达成的具体金额或状态是什么、时间期限是多久；然后帮我定一个具体可衡量的目标，拆成每月的存钱和理财动作，并设置每月一次的复盘提醒。"),
        ("briefcase", "事业",
         "我想创建一个事业方面的目标，请帮我量身定制一个计划。先问我：我目前的职业状态如何、我想在多长时间内达成什么（升职、转行、副业收入等）、我现在的优势和短板是什么；然后帮我定一个具体可衡量的目标，拆成每周可执行的成长动作，并设置每周一次的复盘提醒。"),
        ("paintpalette", "兴趣",
         "我想创建一个兴趣方面的目标，请帮我量身定制一个计划。先问我：我想培养的是什么兴趣、目前是什么水平、想达到什么程度、每周能投入多少时间；然后帮我定一个具体可衡量的目标，拆成每周可执行的练习计划，并设置每周一次的复盘提醒。"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("目标")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, Spacing.lg)

                    // 追踪分组（绿点 + 绿色「追踪」：语义色，保留）
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("追踪")
                            .font(.system(size: Typography.title, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, Spacing.xs)

                    if visibleGoals.isEmpty {
                        Text("还没有目标，从下面的类别开始，或直接告诉 AI。")
                            .font(.system(size: Typography.body))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, Spacing.xl)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(visibleGoals) { g in
                                goalRow(g)
                            }
                        }
                    }

                    // ＋ 创建目标（填进对话框，不直接发）
                    Button {
                        Haptics.tap()
                        onFillInput("我想创建一个新的长期目标，请先问我几个问题了解我的情况（现状、想要的结果、能投入的时间），再帮我量身定制一个具体可衡量的计划，并配上定期复盘提醒。")
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: Typography.title, weight: .medium))
                            Text("创建目标")
                                .font(.system(size: Typography.title, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("创建目标")
                    .padding(.top, 22)

                    Text("选择一个类别，告诉我你想要的目标，我将为你量身定制一个计划，并随着你的成长不断改进。")
                        .font(.system(size: Typography.body))
                        .foregroundStyle(.secondary)
                        .padding(.top, Spacing.md)

                    VStack(spacing: 0) {
                        ForEach(categories.indices, id: \.self) { i in
                            categoryRow(categories[i])
                        }
                    }
                    .padding(.top, Spacing.xl)
                }
                .padding(.horizontal, Spacing.section)
                .padding(.bottom, Spacing.xl)
            }
            .safeAreaBar(edge: .top) {
                topBar
                    .padding(.horizontal, Spacing.section)
                    .padding(.top, Spacing.xl)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await store.loadFromServer() }
            .sheet(isPresented: $showCompleted) { completedSheet }
        }
    }

    // MARK: 顶栏：sidebar / AI 形象胶囊 / "…" 菜单

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                NotificationCenter.default.post(name: .qingliaoToggleSidebar, object: nil)
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: Typography.headline))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .a11yGlass(.clear, in: Circle(), stroke: Color.primary.opacity(0.08))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开侧边栏")

            Spacer(minLength: 0)

            // F 线组件：顶部居中 AI 头像 + 名字胶囊 + 状态小字（无参数）
            AITopCapsule()

            Spacer(minLength: 0)

            // iOS 26 原生 Menu（系统玻璃样式）+ 灰度无彩色
            Menu {
                Picker("字幕", selection: $showSubtitle) {
                    Text("显示字幕").tag(true)
                    Text("隐藏副标题").tag(false)
                }
                Picker("优先显示", selection: $priorityRaw) {
                    Text("追踪").tag("track")
                    Text("目标").tag("goal")
                }
                Divider()
                Button("已完成目标") {
                    Haptics.tap()
                    showCompleted = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: Typography.headline))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .a11yGlass(.clear, in: Circle(), stroke: Color.primary.opacity(0.08))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更多")
        }
    }

    // MARK: 追踪区：未完成目标；优先显示控制排序

    private var visibleGoals: [GoalItem] {
        let active = store.goals.filter { !$0.isFinished }
        guard priorityRaw == "track" else { return active }
        // 追踪优先：未暂停的排前面，同组内按创建时间
        return active.sorted {
            let a = $0.paused ? 1 : 0
            let b = $1.paused ? 1 : 0
            if a != b { return a < b }
            return $0.createdAt < $1.createdAt
        }
    }

    private func goalRow(_ g: GoalItem) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleFinished(g)
                } label: {
                    Image(systemName: g.isFinished ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: Typography.display))
                        .foregroundStyle(g.isFinished ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xxs)
                .accessibilityLabel(g.isFinished ? "标为未完成" : "标为已完成")

                VStack(alignment: .leading, spacing: 6) {
                    Text(g.title)
                        .font(.system(size: Typography.title))
                        .foregroundStyle(.primary)
                    if showSubtitle {
                        let d = goalDesc(g)
                        if !d.isEmpty {
                            Text(d)
                                .font(.system(size: Typography.body))
                                .foregroundStyle(.secondary)
                        }
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
                        .font(.system(size: Typography.title))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("目标操作")
            }
            .padding(.vertical, Spacing.xxl)
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

    // MARK: 已完成目标列表（sheet）

    private var completedSheet: some View {
        NavigationStack {
            Group {
                let done = store.goals.filter { $0.isFinished }
                if done.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("还没有已完成的目标")
                            .font(.system(size: Typography.body))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(done) { g in
                                completedRow(g)
                            }
                        }
                        .padding(.horizontal, Spacing.section)
                    }
                }
            }
            .navigationTitle("已完成目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showCompleted = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func completedRow(_ g: GoalItem) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleFinished(g)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Typography.display))
                        .foregroundStyle(Color.green)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xxs)
                .accessibilityLabel("标为未完成")

                VStack(alignment: .leading, spacing: 6) {
                    Text(g.title)
                        .font(.system(size: Typography.title))
                        .foregroundStyle(.primary)
                    if showSubtitle {
                        let d = goalDesc(g)
                        if !d.isEmpty {
                            Text(d)
                                .font(.system(size: Typography.body))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.xxl)
            Divider()
        }
    }

    // MARK: 类别行：点 + → 详细提示词填进对话框（不直接发）

    private func categoryRow(_ c: (icon: String, name: String, prompt: String)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: c.icon)
                .font(.system(size: Typography.headline))
                .foregroundStyle(.secondary)
                .frame(width: 30)
            Text(c.name)
                .font(.system(size: Typography.title))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Button {
                Haptics.tap()
                onFillInput(c.prompt)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: Typography.title))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("创建\(c.name)目标")
        }
        .padding(.vertical, Spacing.xl)
    }
}
