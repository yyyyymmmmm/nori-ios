import SwiftUI

/// Real, local permission controls. Remote Hermes tool authorization remains owned by Hermes.
struct PermissionCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPermissionKit.confirmReadActionsKey) private var confirmReads = false
    @State private var showDevicePermissions = false
    @State private var showServiceSettings = false
    @State private var aiEnabledCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section(title: "操作确认") {
                        policyRow(
                            title: "写入和删除前询问",
                            subtitle: "只读信息自动读取；写入和删除需要你确认。",
                            selected: !confirmReads
                        ) { confirmReads = false }
                        MuseRowDivider()
                        policyRow(
                            title: "每次操作前询问",
                            subtitle: "只读信息也要你点按；写入和删除仍需单独确认。",
                            selected: confirmReads
                        ) { confirmReads = true }
                    }

                    section(title: "管理本机权限") {
                        navigationRow(
                            title: "本机应用与数据",
                            subtitle: "日历、提醒、照片、联系人、健康等",
                            value: "已允许 AI 使用 \(aiEnabledCount) 项",
                            icon: "iphone.and.arrow.forward"
                        ) { showDevicePermissions = true }
                    }

                    section(title: "云端工具") {
                        navigationRow(
                            title: "Hermes 服务与工具",
                            subtitle: "查看已配置的 MCP、邮件和其他服务",
                            value: nil,
                            icon: "wrench.and.screwdriver"
                        ) { showServiceSettings = true }
                        Text("云端工具的执行权限由 Hermes 与后端配置控制。当前后端没有供 Nori 统一修改连接器或定时任务授权策略的接口；这里不会显示虚假的授权开关。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                    }

                    section(title: "当前确认方式") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("读取：\(confirmReads ? "每次点按后执行" : "自动执行")", systemImage: "eye")
                            Label("写入：在对话卡片中点“执行”", systemImage: "square.and.pencil")
                            Label("删除：单独确认，支持短暂撤销", systemImage: "trash")
                            Label("后台：App 不在前台时拒绝本机写入", systemImage: "lock")
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("权限与审批")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { refreshEnabledCount() }
            .sheet(isPresented: $showDevicePermissions) {
                ConnectAppsView(mode: .devicePermissions)
            }
            .sheet(isPresented: $showServiceSettings) {
                ConnectAppsView(mode: .services)
            }
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0, content: content)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func policyRow(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func navigationRow(title: String, subtitle: String, value: String?, icon: String, action: @escaping () -> Void) -> some View {
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
                    Text(title).font(.system(size: 16)).foregroundStyle(.primary)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func refreshEnabledCount() {
        aiEnabledCount = AppCapability.allCases.filter {
            $0.aiControllable && AppPermissionKit.aiControlEnabled($0)
        }.count
    }
}
