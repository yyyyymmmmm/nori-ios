// 灰度重做 B 路 2026-10-06：设置页视觉组件（对标 Today 设置参考图）。
// 只管视觉结构：分组标题(17pt 灰) + 圆角20玻璃卡片 + 标题17/副标题15/无图标行 + 右绿 Toggle。
// 所有跳转行为由调用方原样保留，这里不碰任何业务逻辑。

import SwiftUI

// MARK: - 分组：灰色分组标题 + 圆角 20 玻璃卡片（行与行之间无分割线）

struct GraySettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
            }
            VStack(spacing: 0) {
                content
            }
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - 普通行：标题(17 medium) + 副标题(15 灰) + 右侧值(15) + 灰 chevron，无行图标

struct GraySettingsRow: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var chevron: Bool = true
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 15))
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
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 静态行（不可点，如已登录用户名）

struct GraySettingsStaticRow: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}

// MARK: - 开关行：标题+副标题在左，绿色 Toggle 在右

struct GraySettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn).qingliaoSwitch()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}
