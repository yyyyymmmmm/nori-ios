import SwiftUI

// MARK: - 灰度重做 2026-10-06：5 Tab IA 新视图
//
// 对话/资讯/点子/目标/我的（对标 TodayAI 参考）。
// 点子/目标复用官方 LifeView 的现成栏目（MemoSection/GoalsSection），不另起功能。

/// 点子 tab：备忘录（灵感记录）
struct IdeasTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    PageHeader(title: "点子", subtitle: "灵感与备忘")
                    MemoSection()
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 100)   // 给悬浮 tab bar 留空
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// 目标 tab：长期目标
struct GoalsTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    PageHeader(title: "目标", subtitle: "长期目标与进展")
                    GoalsSection()
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 100)   // 给悬浮 tab bar 留空
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - 灰度重做 2026-10-06 晚：资讯 tab = 动态 feed（对标 Muse「动态」）
//
// 按时间倒序的信息流，内容来自备忘（点子）——一个功能一个入口，
// 这里只做「看」，编辑/新增仍在点子页。

/// 资讯 tab：动态信息流
struct FeedTabView: View {
    // MemoStore 是 @Observable 单例，直接读 shared.memos 即可驱动刷新
    private var memos: [MemoItem] { MemoStore.shared.memos.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    PageHeader(title: "资讯", subtitle: "动态信息流")
                    if memos.isEmpty {
                        feedEmptyState
                    } else {
                        LazyVStack(spacing: Spacing.sm) {
                            ForEach(memos) { memo in
                                FeedMemoCard(memo: memo)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 100)   // 给悬浮 tab bar 留空
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var feedEmptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "newspaper")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("还没有动态")
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundStyle(.secondary)
            Text("在点子页记一条备忘，它会按时间出现在这里")
                .font(.system(size: Typography.caption))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

/// 动态流里的一条备忘卡片（只读；灰度、无彩色）
private struct FeedMemoCard: View {
    let memo: MemoItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(memo.content)
                .font(.system(size: Typography.body))
                .foregroundStyle(.primary)
                .lineSpacing(4)
            HStack(spacing: Spacing.xs) {
                Text(feedTimeText(memo.createdAt))
                    .font(.system(size: Typography.caption))
                    .foregroundStyle(.tertiary)
                if memo.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func feedTimeText(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "刚刚" }
        if mins < 60 { return "\(mins) 分钟前" }
        let hours = mins / 60
        if hours < 24 { return "\(hours) 小时前" }
        let days = hours / 24
        if days < 30 { return "\(days) 天前" }
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }
}

// MARK: - 灰度重做：悬浮胶囊 tab bar（对标 TodayAI 参考）
//
// 灰图标 + 选中态灰色胶囊高亮，不再是蓝色。
// 用 .plain 按钮样式确保可点（旧版"点不动"教训：悬浮层别挡触摸）。

struct GrayCapsuleTabBar: View {
    @Binding var selected: DockTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DockTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 21))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selected == tab ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(selected == tab ? Color.primary.opacity(0.09) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 5)
        .padding(.horizontal, 18)
    }
}
