// Native app permissions and AI access, backed by iOS authorization state.
import AVFAudio
import SwiftUI
import UIKit

struct ConnectAppsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var states: [AppCapability: PermissionState] = [:]
    @State private var micState: PermissionState = .notDetermined
    @State private var query = ""
    @State private var presented: PresentedSheet?
    @State private var requesting = false

    /// Only apps whose iOS permission or local operation is actually implemented.
    private let capabilities: [AppCapability] = [
        .calendar, .reminders, .contacts, .photos, .location, .health, .homekit
    ]

    private var allApps: [ConnectApp] {
        capabilities.map(ConnectApp.capability) + [.microphone]
    }
    private var visibleApps: [ConnectApp] {
        guard !query.isEmpty else { return allApps }
        return allApps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    private func state(_ app: ConnectApp) -> PermissionState {
        switch app {
        case .capability(let cap): states[cap] ?? .notDetermined
        case .microphone: micState
        }
    }
    private var connectedApps: [ConnectApp] { visibleApps.filter { state($0) == .granted } }
    private var availableApps: [ConnectApp] {
        visibleApps.filter { state($0) != .granted && state($0) != .unavailable }
    }
    private var unavailableApps: [ConnectApp] { visibleApps.filter { state($0) == .unavailable } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    searchField
                    appSection("已连接", apps: connectedApps, mode: .connected)
                    appSection("可用", apps: availableApps, mode: .available)
                    if !unavailableApps.isEmpty {
                        appSection("当前设备不可用", apps: unavailableApps, mode: .unavailable)
                    }
                    cloudManagers
                    if visibleApps.isEmpty {
                        ContentUnavailableView("没有匹配的应用", systemImage: "magnifyingglass")
                            .padding(.top, 28)
                    }
                    Text("授权状态由 iOS 实时提供。系统权限只允许 Nori 访问对应数据；是否允许 AI 使用，还要由下方的 AI 操作开关控制。云端服务在各自的连接设置中管理。")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("连接应用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { Haptics.tap(); dismiss() }
                }
            }
            .task { await refresh() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await refresh() }
            }
            .sheet(item: $presented) { item in
                Group {
                    switch item {
                    case .intro(let app):
                        ConnectAppIntroSheet(app: app, state: state(app)) { await connect(app) }
                    case .detail(let app):
                        ConnectAppDetailSheet(app: app, state: state(app), refresh: {
                            await refresh()
                            return state(app)
                        }) { await connect(app) }
                    case .tools: MCPSettingsSheet().scrollContentBackground(.hidden)
                    case .thirdParty: ThirdPartyView()
                    case .mail: MailSettingsSheet().scrollContentBackground(.hidden)
                    case .cloudDrive: CloudDriveSettingsSheet().scrollContentBackground(.hidden)
                    case .homeAssistant: HASettingsSheet()
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索连接应用", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .font(.system(size: 17))
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
    }

    private var cloudManagers: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在线服务与工具")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                cloudRow("工具服务（MCP）", subtitle: "查看和管理 Hermes 可调用的工具", icon: "hammer") { presented = .tools }
                MuseRowDivider()
                cloudRow("对接第三方", subtitle: "消息渠道与 OAuth 授权", icon: "square.grid.2x2") { presented = .thirdParty }
                MuseRowDivider()
                cloudRow("邮件", subtitle: "查看和管理已配置的邮箱账号", icon: "envelope") { presented = .mail }
                MuseRowDivider()
                cloudRow("网盘", subtitle: "查看和管理已接入的网盘", icon: "externaldrive") { presented = .cloudDrive }
                MuseRowDivider()
                cloudRow("Home Assistant", subtitle: "配置智能家居连接", icon: "house") { presented = .homeAssistant }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func cloudRow(_ title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 13) {
                Image(systemName: icon).font(.system(size: 21)).frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17)).foregroundStyle(.primary)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private enum SectionMode { case connected, available, unavailable }

    @ViewBuilder
    private func appSection(_ title: String, apps: [ConnectApp], mode: SectionMode) -> some View {
        if !apps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                VStack(spacing: 0) {
                    ForEach(apps) { app in
                        appRow(app, mode: mode)
                        if app.id != apps.last?.id { MuseRowDivider() }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func appRow(_ app: ConnectApp, mode: SectionMode) -> some View {
        Button {
            Haptics.tap()
            switch mode {
            case .connected: presented = .detail(app)
            case .available: presented = .intro(app)
            case .unavailable: presented = .detail(app)
            }
        } label: {
            HStack(spacing: 13) {
                app.icon.frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.system(size: 17)).foregroundStyle(.primary)
                    Text(mode == .connected ? "已授权" : mode == .unavailable ? "此安装版本不支持" : app.shortSummary)
                        .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                if mode == .available {
                    Text(state(app) == .denied || state(app) == .restricted ? "设置" : "连接")
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func refresh() async {
        for cap in capabilities { states[cap] = await AppPermissionKit.status(of: cap) }
        micState = AVAudioSession.sharedInstance().recordPermission.toPermissionState()
    }

    @MainActor
    private func connect(_ app: ConnectApp) async -> PermissionState {
        guard !requesting else { return state(app) }
        requesting = true
        defer { requesting = false }
        let result: PermissionState
        switch app {
        case .capability(let cap): result = await AppPermissionKit.request(cap)
        case .microphone:
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { _ in continuation.resume() }
            }
            result = AVAudioSession.sharedInstance().recordPermission.toPermissionState()
        }
        await refresh()
        if result == .denied || result == .restricted { openSystemSettings() }
        return result
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private enum ConnectApp: Identifiable, Hashable {
    case capability(AppCapability)
    case microphone

    var id: String {
        switch self {
        case .capability(let cap): "cap-\(cap.rawValue)"
        case .microphone: "microphone"
        }
    }
    var name: String {
        switch self {
        case .capability(let cap): cap.displayName
        case .microphone: "麦克风"
        }
    }
    var summary: String {
        switch self {
        case .capability(let cap): cap.blurb
        case .microphone: "语音输入与语音对话"
        }
    }
    var shortSummary: String {
        switch self {
        case .capability(.calendar): "日程读取与经确认的编辑"
        case .capability(.reminders): "提醒读取与经确认的管理"
        case .capability(.contacts): "联系人查询与经确认的新建"
        case .capability(.photos): "读取授权照片与经确认的保存"
        case .capability(.location): "按需读取当前位置"
        case .capability(.health): "健康数据只读"
        case .capability(.homekit): "智能家居控制"
        case .microphone: "语音输入与语音对话"
        default: summary
        }
    }
    var icon: AnyView {
        switch self {
        case .capability(let cap):
            if let kind = cap.appleStyleKind {
                return AnyView(SystemAppIconView(bundleID: cap.systemAppBundleID, fallback: kind, size: 42))
            }
            return AnyView(Image(systemName: cap.sfSymbol).font(.system(size: 23)).foregroundStyle(.primary))
        case .microphone:
            return AnyView(Image(systemName: "mic.fill").font(.system(size: 22)).foregroundStyle(.blue))
        }
    }
    var permissions: [(String, String)] {
        switch self {
        case .capability(.calendar): [("读取", "查看日程与空闲时间"), ("写入", "经你确认后新建、修改或删除事件")]
        case .capability(.reminders): [("读取", "查看提醒事项"), ("写入", "经你确认后新建或删除提醒")]
        case .capability(.contacts): [("读取", "按姓名或号码查找联系人"), ("写入", "经你确认后新建联系人")]
        case .capability(.photos): [("读取", "读取你授权范围内的照片"), ("写入", "经你确认后保存或删除照片")]
        case .capability(.location): [("读取", "仅在请求时读取当前位置")]
        case .capability(.health): [("读取", "读取健康摘要；只读")]
        case .capability(.homekit): [("状态", "当前侧载版本未获得 HomeKit entitlement")]
        case .microphone: [("输入", "录制语音用于语音输入与对话")]
        default: [("访问", summary)]
        }
    }
    var aiCapability: AppCapability? {
        if case .capability(let cap) = self { return cap }
        return nil
    }
}

private enum PresentedSheet: Identifiable {
    case intro(ConnectApp)
    case detail(ConnectApp)
    case tools
    case thirdParty
    case mail
    case cloudDrive
    case homeAssistant
    var id: String {
        switch self {
        case .intro(let app): "intro-\(app.id)"
        case .detail(let app): "detail-\(app.id)"
        case .tools: "tools"
        case .thirdParty: "third-party"
        case .mail: "mail"
        case .cloudDrive: "cloud-drive"
        case .homeAssistant: "home-assistant"
        }
    }
}

private struct ConnectAppIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    let app: ConnectApp
    let state: PermissionState
    let connect: () async -> PermissionState
    @State private var working = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.tertiary).frame(width: 38, height: 5).padding(.top, 10)
            ScrollView {
                VStack(spacing: 18) {
                    app.icon.frame(width: 60, height: 60).padding(.top, 22)
                    Text(app.name).font(.system(size: 25, weight: .semibold))
                    Text("Nori 需要通过 iOS 授权才能访问此应用的数据。你可以随时在系统设置中撤销权限。")
                        .font(.system(size: 16)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(app.permissions, id: \.0) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.0 == "读取" ? "eye" : "slider.horizontal.3")
                                    .frame(width: 22).font(.system(size: 18, weight: .medium))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.0).font(.system(size: 16, weight: .semibold))
                                    Text(item.1).font(.system(size: 14)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
            Button {
                guard !working else { return }
                working = true
                Task { _ = await connect(); working = false; dismiss() }
            } label: {
                Group { if working { ProgressView().tint(.white) } else { Text(state == .denied || state == .restricted ? "前往系统设置" : "继续") } }
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .foregroundStyle(.white).background(Color.accentColor, in: Capsule())
            }
            .disabled(working || state == .unavailable)
            .padding(.horizontal, 22)
            Button("取消") { dismiss() }
                .font(.system(size: 16, weight: .medium)).padding(.top, 16).padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct ConnectAppDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let app: ConnectApp
    @State private var permissionState: PermissionState
    let refresh: () async -> PermissionState
    let connect: () async -> PermissionState
    @State private var aiOn = false
    @State private var masterOn = AppPermissionKit.aiControlMasterEnabled

    init(app: ConnectApp, state: PermissionState,
         refresh: @escaping () async -> PermissionState,
         connect: @escaping () async -> PermissionState) {
        self.app = app
        self._permissionState = State(initialValue: state)
        self.refresh = refresh
        self.connect = connect
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        app.icon.frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name).font(.system(size: 20, weight: .semibold))
                            Label(statusText, systemImage: permissionState == .granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                                .font(.system(size: 14)).foregroundStyle(permissionState == .granted ? .green : .secondary)
                        }
                    }.padding(.vertical, 8)
                }
                Section("访问范围") {
                    ForEach(app.permissions, id: \.0) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.0).font(.system(size: 16, weight: .medium))
                            Text(item.1).font(.system(size: 14)).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                }
                if let cap = app.aiCapability, cap.aiControllable {
                    Section("AI 使用权限") {
                        Toggle("允许 AI 操作\(app.name)", isOn: $aiOn)
                            .disabled(permissionState != .granted || !masterOn)
                            .onChange(of: aiOn) { _, newValue in AppPermissionKit.setAIControlEnabled(newValue, for: cap) }
                        Toggle("允许 AI 操作本机数据（总开关）", isOn: $masterOn)
                            .onChange(of: masterOn) { _, newValue in AppPermissionKit.aiControlMasterEnabled = newValue }
                        if !masterOn {
                            Text("总开关关闭时，AI 对所有本机应用的操作都会被拦截。")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Button(permissionState == .denied || permissionState == .restricted ? "打开 iOS 设置" : permissionState == .granted ? "在 iOS 设置中管理权限" : "连接并请求权限") {
                        if permissionState == .notDetermined { Task { permissionState = await connect() } }
                        else if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .disabled(permissionState == .unavailable)
                } footer: {
                    Text(permissionState == .granted
                         ? "iOS 授权已生效。访问范围由系统授权与 Nori 已实现的操作共同决定。"
                         : permissionState == .unavailable ? "此能力在当前安装方式下不可用。" : "Nori 不会绕过 iOS 权限提示。")
                }
            }
            .navigationTitle("连接详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task {
                if let cap = app.aiCapability { aiOn = AppPermissionKit.aiControlEnabled(cap) }
                masterOn = AppPermissionKit.aiControlMasterEnabled
                permissionState = await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { permissionState = await refresh() }
            }
        }
    }

    private var statusText: String {
        switch permissionState {
        case .granted: "已连接 · 系统授权有效"
        case .notDetermined: "尚未授权"
        case .denied: "权限已拒绝"
        case .restricted: "受系统限制"
        case .unavailable: "当前安装版本不可用"
        }
    }
}

private extension AVAudioSession.RecordPermission {
    func toPermissionState() -> PermissionState {
        switch self {
        case .granted: .granted
        case .denied: .denied
        case .undetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}
