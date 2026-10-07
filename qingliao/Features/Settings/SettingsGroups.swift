// 2026-10-07 设置页一级/二级重构：
// 一级页用搜索框与分类行承载入口；各组内容统一进入二级页，复用 GraySettingsGroup。

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
        case .profile: "账户 · 登录与安全"
        case .ai: "Hermes 记忆 · 定时任务 · 技能"
        case .connector: "AI连接 · 服务与工具"
        case .general: "外观 · 朗读声音 · 快捷方式"
        case .notify: "本地提醒"
        case .about: "关于 · 帮助与支持 · 问题反馈"
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
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: Typography.rowTitle))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 直达型设置分类（凭证库、消息渠道、设备权限）：保持与 push 分类相同的行样式。
struct SettingsGroupActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var value: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: Typography.rowTitle)).foregroundStyle(.primary)
                    Text(subtitle).font(.system(size: Typography.subhead)).foregroundStyle(.tertiary).lineLimit(2)
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value).font(.system(size: Typography.subhead)).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 二级页外壳（ScrollView + 导航标题；不套 NavigationStack，用外层栈的 push）

struct SettingsSubpageView<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
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
