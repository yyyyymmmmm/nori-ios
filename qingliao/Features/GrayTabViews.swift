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
