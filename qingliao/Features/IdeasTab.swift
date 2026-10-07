import SwiftUI

// MARK: - H 线：点子 tab = AI 动态推荐（对标 Muse 点子页）
//
// 顶部 chrome：左 sidebar / 中 AITopCapsule（F 线组件）/ 右无按钮（用户要求去掉 +）
// + 大标题「点子」。
// 内容：AI 生成的个性化推荐卡片（图标 + 加粗标题 + 灰色详细描述），按 group 分组；
// 顶部 loading；下拉刷新；后端/AI 不通回退内置模板（IdeasStore.fallbackTemplates）。
// 交互：点卡片 → onFillInput(完整提示词)，填进对话输入框，用户自己发送（不自动发）。

struct IdeasTabView: View {
    /// 填进对话页输入框的唯一出口（DockTabView 侧：切聊天页 + 填入输入框，不自动发送）
    let onFillInput: (String) -> Void
    @State private var store = IdeasStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("点子")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, Spacing.lg)
                    if store.isLoading && store.ideas.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ideaGroups
                    }
                }
                .padding(.horizontal, Spacing.section)
                .padding(.bottom, Spacing.xl)
            }
            .scrollEdgeEffectHidden(true)
            .safeAreaBar(edge: .top) {
                topBar
                    .padding(.horizontal, Spacing.section)
                    .padding(.top, Spacing.xl)
                    .background(.clear)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await store.refresh() }
            .refreshable { await store.refresh(force: true) }
        }
    }

    // MARK: 顶栏：sidebar / AI 形象胶囊 / 右占位（+ 已按用户要求去掉）

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

            // 右上占位：+ 按钮已去掉；留 44pt 保证胶囊居中
            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    // MARK: 分组（保持首次出现顺序）

    private struct IdeaGroup: Identifiable {
        var name: String?
        var ideas: [AIdea]
        var id: String { name ?? "__ungrouped" }
    }

    private var grouped: [IdeaGroup] {
        var order: [String] = []
        var map: [String: [AIdea]] = [:]
        var ungrouped: [AIdea] = []
        for idea in store.ideas {
            if let g = idea.group, !g.isEmpty {
                if map[g] == nil { order.append(g) }
                map[g, default: []].append(idea)
            } else {
                ungrouped.append(idea)
            }
        }
        var result: [IdeaGroup] = []
        if !ungrouped.isEmpty { result.append(IdeaGroup(name: nil, ideas: ungrouped)) }
        for g in order { result.append(IdeaGroup(name: g, ideas: map[g] ?? [])) }
        return result
    }

    private var ideaGroups: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(grouped) { g in
                if let name = g.name {
                    Text(name)
                        .font(.system(size: Typography.title, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.top, 20)
                        .padding(.bottom, Spacing.xs)
                }
                VStack(spacing: 0) {
                    ForEach(g.ideas) { idea in
                        Button {
                            Haptics.tap()
                            onFillInput(idea.prompt)
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: idea.icon)
                                    .font(.system(size: Typography.titleXL, weight: .light))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 34, alignment: .top)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(idea.title)
                                        .font(.system(size: Typography.title, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(idea.desc)
                                        .font(.system(size: Typography.body))
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(3)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Spacing.xxl)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("用「\(idea.title)」问 AI")
                        Divider()
                    }
                }
            }
            // 兜底时诚实标注（不假装是 AI 生成的）
            if store.isFallback {
                Text("AI 推荐暂不可用，当前显示为内置推荐")
                    .font(.system(size: Typography.subhead))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            }
        }
    }
}
