// 2026-10-07 设置页一级/二级重构：
// 一级页只剩 AI 形象大卡 + 搜索框 + 6 个分组行；每组内容（原 6 个 Section builder）
// 整体搬进二级页，GraySettingsGroup 原样复用。只搬行、不改功能。

import SwiftUI

// MARK: - 二级页枚举（一级页 6 个分组行 + 搜索直达共用）

/// 大厂顺序：个人中心在前。
enum SettingsSubpage: String, Hashable, Identifiable, CaseIterable {
    case profile, ai, connector, general, notify, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: "个人中心"
        case .ai: "AI设置"
        case .connector: "连接器"
        case .general: "通用设置"
        case .notify: "通知"
        case .about: "关于我们"
        }
    }

    var icon: String {
        switch self {
        case .profile: "person.circle"
        case .ai: "sparkles"
        case .connector: "link"
        case .general: "gearshape"
        case .notify: "bell"
        case .about: "info.circle"
        }
    }

    /// 分组行副标题摘要（一眼看出组里有什么）
    var subtitle: String {
        switch self {
        case .profile: "账号 · 密码 · Face ID"
        case .ai: "Hermes 记忆 · 定时任务 · 技能"
        case .connector: "连接设置 · 连接应用 · 工具服务"
        case .general: "外观 · 朗读声音 · 快捷方式"
        case .notify: "本地提醒"
        case .about: "版本 · 日志 · 诊断"
        }
    }
}

// MARK: - 一级页分组行（NavigationLink，行样式与 GraySettingsRow 对齐）

struct SettingsGroupLink<Destination: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let destination: () -> Destination

    init(icon: String, title: String, subtitle: String,
         @ViewBuilder destination: @escaping () -> Destination) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.primary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 二级页外壳（ScrollView + 导航标题；不套 NavigationStack，用外层栈的 push）

struct SettingsSubpageView<Content: View>: View {
    let title: String
    let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // 2026-10-07 真机反馈：push 转场抖动——根因是一级页 toolbar hidden、
            // 二级页 toolbar visible，导航栏显隐切换导致内容跳动。
            // 改：二级页也保持 toolbar hidden，chrome 前后一致；返回用自定义左箭头
            //（样式与一级页"标题+X 关闭"自定义头统一：44pt 触区、headline 居中标题）。
            HStack {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: Typography.title, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .a11yGlass(.regular, in: Circle(), stroke: Color.primary.opacity(0.08))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                Spacer()
                Text(title)
                    .font(.system(size: Typography.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Color.clear.frame(width: 44, height: 44) // 与左箭头对称，标题真正居中
            }
            .padding(.horizontal, Spacing.section)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
            ScrollView {
                VStack(spacing: 28) {
                    content()
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.top, Spacing.md)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        // 2026-10-07 真机反馈：自定义返回头干掉了系统侧滑返回。补左边缘右滑手势
        //（28pt 透明条，不挡纵向滚动；右滑 >70pt 且纵向 <50pt 触发返回）。
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { v in
                            if v.translation.width > 70 && abs(v.translation.height) < 50 {
                                Haptics.tap()
                                dismiss()
                            }
                        }
                )
        }
    }
}

// MARK: - 6 个二级页（原 6 个 Section builder 整体搬入，GraySettingsGroup 原样复用）

extension SettingsView {

    /// 二级页分发（一级页分组行直连各 page；搜索 sec:xxx 直达走这里）
    @ViewBuilder func subpage(for page: SettingsSubpage) -> some View {
        switch page {
        case .profile: profilePage
        case .ai: aiSettingsPage
        case .connector: connectorPage
        case .general: generalSettingsPage
        case .notify: notifyPage
        case .about: aboutPage
        }
    }

    /// 一级页分组行（6 行，大厂顺序）
    @ViewBuilder func groupLink(_ page: SettingsSubpage) -> some View {
        SettingsGroupLink(icon: page.icon, title: page.title, subtitle: page.subtitle) {
            subpage(for: page)
        }
    }

    /// 个人中心 ← 原 accountSection（账号与安全）
    @ViewBuilder var profilePage: some View {
        SettingsSubpageView(title: SettingsSubpage.profile.title) { accountSection }
    }

    /// AI设置 ← 原 agentSection（智能体）
    @ViewBuilder var aiSettingsPage: some View {
        SettingsSubpageView(title: SettingsSubpage.ai.title) { agentSection }
    }

    /// 连接器 ← 原 connectionSection（连接）
    @ViewBuilder var connectorPage: some View {
        SettingsSubpageView(title: SettingsSubpage.connector.title) { connectionSection }
    }

    /// 通用设置 ← 原 generalSection（通用）
    @ViewBuilder var generalSettingsPage: some View {
        SettingsSubpageView(title: SettingsSubpage.general.title) { generalSection }
    }

    /// 通知 ← 原 notificationSection
    @ViewBuilder var notifyPage: some View {
        SettingsSubpageView(title: SettingsSubpage.notify.title) { notificationSection }
    }

    /// 关于我们 ← 原 aboutSection（关于）
    @ViewBuilder var aboutPage: some View {
        SettingsSubpageView(title: SettingsSubpage.about.title) { aboutSection }
    }
}
