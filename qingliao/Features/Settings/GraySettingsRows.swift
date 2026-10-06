// J 线 2026-10-06：设置页视觉组件（对标 Muse 设置参考图）。
// 行 = 单色线条图标 + 标题(17) + 副标题(15) + 右侧值(15) + 灰 chevron；
// 分组 = 圆角 16 实色卡片（行间细分割线由调用方用 MuseRowDivider 显式插入）；
// iOS 26 玻璃只用在顶栏按钮，卡片一律实色（深色模式自适应）。

import SwiftUI

// MARK: - 分组：分组标题 + 圆角 16 实色卡片

struct GraySettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
            }
            VStack(spacing: 0) {
                content
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - 行间细分割线（Muse 式：左端对齐图标右缘）

struct MuseRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 52)
    }
}

// MARK: - 普通行：图标 + 标题/副标题 + 右侧值 + 灰 chevron

struct GraySettingsRow: View {
    var icon: String? = nil
    var colorful: Bool = false   // K 线：连接应用页用多彩图标（SF Symbol multicolor）
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var chevron: Bool = true
    var action: () -> Void = {}

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                if let icon {
                    Group {
                        if colorful {
                            Image(systemName: icon)
                                .symbolRenderingMode(.multicolor)
                        } else {
                            Image(systemName: icon)
                                .foregroundStyle(.primary)
                        }
                    }
                    .font(.system(size: 22))
                    .frame(width: 30)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 静态行（不可点）

struct GraySettingsStaticRow: View {
    var icon: String? = nil
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.primary)
                    .frame(width: 30)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - 开关行：图标 + 标题/副标题在左，系统 Toggle 在右

struct GraySettingsToggleRow: View {
    var icon: String? = nil
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.primary)
                    .frame(width: 30)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn).qingliaoSwitch()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
