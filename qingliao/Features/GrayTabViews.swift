import SwiftUI

// MARK: - 灰度重做：悬浮胶囊 tab bar（对标 TodayAI 参考）
//
// 灰图标 + 选中态灰色胶囊高亮，不再是蓝色。
// 用 .plain 按钮样式确保可点（旧版"点不动"教训：悬浮层别挡触摸）。
//
// 2026-10-06 晚（C 路）：三个 tab 视图已拆出独立文件 ——
//   资讯 → FeedTab.swift（Muse「动态」feed）
//   点子 → IdeasTab.swift（AI 推荐任务）
//   目标 → GoalsTab.swift（Muse「目标」页）
// 本文件只保留 tab bar（别动）。

struct GrayCapsuleTabBar: View {
    @Binding var selected: DockTab

    /// 本体高度估算（图标 21 + 间距 3 + 文字 ~13 + 内边距 9*2 + 外边距 7*2 ≈ 70）。
    /// 聊天页输入框避让用：inset = bodyHeight + bottomGap + safeArea.bottom。
    /// ⚠️ 改这里的内外边距/字号时同步改这个数（真机以渲染为准，估算只用于避让）。
    static let bodyHeight: CGFloat = 70
    /// 胶囊下方的呼吸（DockTabView 的 VStack 里配套使用，改一处改两处）
    static let bottomGap: CGFloat = 10

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
        .a11yGlass(.regular, in: Capsule(), stroke: Color.primary.opacity(0.06))
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 5)
        .padding(.horizontal, 18)
    }
}
