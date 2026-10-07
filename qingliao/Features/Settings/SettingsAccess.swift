// 本文件由 2026-09-27 工程治理「Settings 物理合并」生成：多份同域设置页文件合并为一，
// UI 入口与行为零改动，仅文件边界变化。合并前各文件的来源见下方 MARK 分段。

import Combine
import Foundation
import LocalAuthentication
import SwiftUI
import UIKit

// MARK: ===== 以下原为 Features/Settings/ConnSettingsView.swift =====

// MARK: - v2.0.83c 连接设置二级页（服务器地址 / 测试连接 / 会话存储位置——从主设置页收进二级）
// v2.0.83f：List 白底改毛玻璃卡片风格（与主设置页 glassListCard 一致）

struct ConnSettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    // v4.0.61：钉一钉存储路径（用户 2026-10-05 要求：从主设置页搬到「连接设置」的「存储」下面）
    @State private var showPinPath = false
    /// v4.0.61 审查 7：搜索「钉一钉存储」直达只认**首次呈现**那一次，关掉后本页再出现不再自动弹
    @State private var didAutoOpenPinPath = false
    /// 搜索「钉一钉存储」直达：主设置页以 true 呈现本页时，进页即弹出该 sheet（免得再点一次）
    var initiallyShowPinPath: Bool = false
    @State private var showServerSheet = false
    @State private var showSessionLocSheet = false
    @State private var showUploadDirSheet = false   // v2.0.85 文件上传位置
    // v4.4.x：连接中心——服务状态（后端 /api/connections）
    @State private var connections: [ConnectionInfo] = []
    @State private var showHADetail = false
    @State private var showNASDetail = false
    // v4.4.x：模型选择（后端 /api/agent/hermes/models）
    @State private var showModelPicker = false

    private var currentHermesModel: String {
        UserDefaults.standard.string(forKey: "qingliao_model") ?? ""
    }
    @State private var sessionLoc = ""
    @State private var uploadDir = ""
    @State private var testResult: String?
    @State private var testing = false

    private var shortServer: String {
        auth.serverURL
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
    }

    private var sessionLocShort: String {
        let parts = sessionLoc.split(separator: "/").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "…/" + parts.suffix(2).joined(separator: "/")
        }
        return sessionLoc.isEmpty ? "默认" : sessionLoc
    }

    /// v4.0.61：钉一钉存储路径短显（与主设置页原样同款；PinStore 单例 = App 内单一真源）
    private var pinPathDisplay: String {
        let p = PinStore.shared.storagePath
        return p.isEmpty ? "默认路径" : (p.count > 20 ? "..." + p.suffix(17) : p)
    }

    /// v2.0.85：上传目录短显（取路径后两段）
    private var uploadDirShort: String {
        let parts = uploadDir.split(separator: "/").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "…/" + parts.suffix(2).joined(separator: "/")
        }
        return uploadDir.isEmpty ? "默认" : uploadDir
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // J 线 2026-10-06：模型（原「模型管理」独立页迁入此处）
                    Text("模型")
                        .font(.system(size: Typography.subhead, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.xs)
                    VStack(spacing: 0) {
                        SettingRow(icon: "cpu", iconColor: .green,
                                   title: "当前模型", value: currentHermesModel.isEmpty ? "未设置" : currentHermesModel,
                                   chevron: true)
                            .onTapGesture {
                                Haptics.tap()
                                showModelPicker = true
                            }
                    }
                    .glassListCard()

                    // v4.4.x：连接中心——服务状态（2026-10-07 重设计：卡片式对齐大厂）
                    Text("服务")
                        .font(.system(size: Typography.subhead, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.xs)
                        .padding(.top, Spacing.sm)
                    VStack(spacing: 0) {
                        ForEach(connections.indices, id: \.self) { index in
                            let conn = connections[index]
                            Button {
                                if conn.id == "homeassistant" {
                                    Haptics.tap()
                                    showHADetail = true
                                } else if conn.id == "nas" {
                                    Haptics.tap()
                                    showNASDetail = true
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    // 服务图标
                                    Image(systemName: connIcon(for: conn.id))
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white)
                                        .frame(width: 48, height: 48)
                                        .background(connColor(for: conn.id), in: RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conn.name)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(conn.configured ? Color.green : Color.gray.opacity(0.4))
                                                .frame(width: 8, height: 8)
                                            Text(conn.configured ? "已连接" : "未配置")
                                                .font(.system(size: 13))
                                                .foregroundStyle(conn.configured ? .green : .secondary)
                                            if let note = conn.note, !note.isEmpty {
                                                Text("· \(note)")
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    Spacer(minLength: 8)
                                    if conn.editable {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if index < connections.count - 1 {
                                MuseRowDivider().padding(.leading, 78)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .task {
                        await loadConnections()
                    }
                    .sheet(isPresented: $showHADetail) {
                        HomeAssistantDetailView()
                    }
                    .sheet(isPresented: $showNASDetail) {
                        NASDetailView()
                    }

                    Text("服务器")
                        .font(.system(size: Typography.subhead, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.xs)
                    VStack(spacing: 0) {
                        SettingRow(icon: "globe.asia.australia.fill", iconColor: .green,
                                   title: "服务器地址", value: shortServer, chevron: true)
                            .onTapGesture { showServerSheet = true }
                        Divider().padding(.leading, Spacing.rowDividerInset)
                        SettingRow(icon: "network", iconColor: .blue,
                                   title: "测试连接", value: testing ? "检测中..." : nil,
                                   chevron: !testing)
                            .onTapGesture { testConnection() }
                        if let r = testResult {
                            Text(r)
                                .font(.system(size: Typography.caption))
                                .foregroundStyle(r.hasPrefix("✅") ? Color.green : Color.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Spacing.xxl)
                                .padding(.bottom, Spacing.md)
                                .padding(.top, Spacing.xxs)
                        }
                    }
                    .glassListCard()

                    Text("存储")
                        .font(.system(size: Typography.subhead, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.xs)
                        .padding(.top, Spacing.sm)
                    VStack(spacing: 0) {
                        SettingRow(icon: "tray.full.fill", iconColor: .teal,
                                   title: "会话存储位置", value: sessionLocShort, chevron: true)
                            .onTapGesture { showSessionLocSheet = true }
                        Divider().padding(.leading, Spacing.rowDividerInset)
                        // v2.0.85：文件上传位置（App 附件整份上传的落点，可自定义 NAS 目录）
                        SettingRow(icon: "arrow.up.doc.fill", iconColor: .indigo,
                                   title: "文件上传位置", value: uploadDirShort, chevron: true)
                            .onTapGesture { showUploadDirSheet = true }
                        Divider().padding(.leading, Spacing.rowDividerInset)
                        // v4.0.61：钉一钉存储（用户 2026-10-05：由主设置页搬到「存储」下面）
                        SettingRow(icon: "pin.fill", iconColor: .indigo,
                                   title: "钉一钉存储", value: pinPathDisplay, chevron: true)
                            .onTapGesture { showPinPath = true }
                    }
                    .glassListCard()
                    Text("会话记录保存在 NAS 指定目录，Web 与 App 共用同一份")
                        .font(.system(size: Typography.tiny))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, Spacing.xs)
                }
                .padding(Spacing.xxl)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("连接设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showServerSheet) {
                ServerSheet()
            }
            .sheet(isPresented: $showSessionLocSheet) {
                SessionLocSheet(currentPath: sessionLoc)
            }
            // v4.0.61：钉一钉存储路径（自带的统一底部 sheet，形态与原主设置页一致）
            .sheet(isPresented: $showPinPath) {
                PinPathSheet()
            }
            // v2.0.85：文件上传位置修改
            .sheet(isPresented: $showUploadDirSheet) {
                UploadDirSheet(current: uploadDir) { newDir in
                    showUploadDirSheet = false
                    uploadDir = newDir
                }
            }
            // J 线 2026-10-06：模型选择（原「模型管理」独立页迁入）
            .sheet(isPresented: $showModelPicker) {
                HermesModelPickerSheet()
            }
            .onAppear {
                // v4.0.61：搜索「钉一钉存储」直达（只认呈现时那一次，关掉不复发）
                if initiallyShowPinPath && !didAutoOpenPinPath {
                    didAutoOpenPinPath = true
                    showPinPath = true
                }
            }
            .task {
                // 拉取服务器端会话存储位置 + 文件上传位置
                if let j = try? await auth.json("/api/sessions/location") {
                    sessionLoc = j["path"] as? String ?? ""
                }
                if let j = try? await auth.json("/api/files/config") {
                    uploadDir = j["upload_dir"] as? String ?? ""
                }
            }
        }
    }

    private func testConnection() {
        guard !testing else { return }
        testing = true
        Task {
            defer { testing = false }
            do {
                let j = try await auth.json("/api/auth/status")
                let ok = (j["ok"] as? Bool) ?? false
                testResult = ok ? "✅ 连接正常，服务器：\(shortServer)" : "⚠️ 服务器响应异常"
            } catch {
                testResult = "❌ 无法连接：\(shortServer)"
            }
        }
    }

    // v4.4.x：连接中心——加载服务状态
    @MainActor
    private func loadConnections() async {
        do {
            let (data, _) = try await auth.request("/api/connections", method: "GET")
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = obj["connections"] as? [[String: Any]] {
                let decoder = JSONDecoder()
                let jsonData = try JSONSerialization.data(withJSONObject: list)
                connections = (try? decoder.decode([ConnectionInfo].self, from: jsonData)) ?? []
            }
        } catch {
            connections = []
        }
    }

    // 2026-10-07：连接服务图标（重设计）
    private func connIcon(for id: String) -> String {
        switch id {
        case "hermes": return "brain.head.profile"
        case "homeassistant": return "house.fill"
        case "nas": return "externaldrive.fill"
        default: return "link"
        }
    }

    // 2026-10-07：连接服务图标背景色
    private func connColor(for id: String) -> Color {
        switch id {
        case "hermes": return Color(red: 0.35, green: 0.55, blue: 1.0)
        case "homeassistant": return Color(red: 0.2, green: 0.7, blue: 0.9)
        case "nas": return Color(red: 0.5, green: 0.5, blue: 0.55)
        default: return .gray
        }
    }
}

// MARK: - v2.0.85 文件上传位置修改（自定义 NAS 目录）

private struct UploadDirSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var path = ""
    @State private var saving = false
    @State private var result: (ok: Bool, text: String)?
    let current: String
    var onSaved: (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("文件上传位置")
                .font(.system(size: Typography.title, weight: .bold))
                .padding(.top, 20)
            Text("App 发送的附件（PDF/文档等）将整份保存到该 NAS 目录")
                .font(.system(size: Typography.caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            TextField("NAS 绝对路径", text: $path)
                .font(.system(size: Typography.body))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(Spacing.xl)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: Radius.inset, style: .continuous))
                .padding(.horizontal, Spacing.sheetInset)

            if let r = result {
                Text(r.text)
                    .font(.system(size: Typography.subhead))
                    .foregroundStyle(r.ok ? Color.green : Color.red)
                    .padding(.horizontal, Spacing.sheetInset)
            }

            Button {
                save()
            } label: {
                Text(saving ? "保存中..." : "保存")
                    .font(.system(size: Typography.body, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .pill(.primary)
            }
            .buttonStyle(.plain)
            .disabled(saving || path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, Spacing.sheetInset)

            Button("取消") { dismiss() }
                .font(.system(size: Typography.body))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .onAppear { path = current }
    }

    private func save() {
        let p = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty, !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            if let j = try? await auth.json("/api/files/config", method: "POST", body: ["upload_dir": p]) {
                let ok = (j["ok"] as? Bool) ?? false
                result = (ok, j["message"] as? String ?? (ok ? "已保存" : "保存失败"))
                if ok {
                    onSaved(j["upload_dir"] as? String ?? p)
                    dismiss()
                }
            } else {
                result = (false, "请求失败，请检查连接")
            }
        }
    }
}

// MARK: ===== 以下原为 Features/Settings/SecretsView.swift =====

// MARK: - 密码管理（NAS SSH / 路由器 / 其他凭据，服务器端 Fernet 加密存储）

struct SecretEntry: Identifiable {
    let id: String
    var name: String
    var type: String      // nas / router / other
    var address: String
    var username: String
    var hasPassword: Bool
    var password: String = ""   // 明文（仅 reveal 后填充）
}

/// v3.9.41（SR22）：复制出去的凭据 60 秒后自动从系统剪贴板失效
/// （剪贴板会被其他 App 读到、iCloud 通用剪贴板还会上云，不能当保险箱）
enum SecretClipboard {
    static func copy(_ s: String) {
        // UIPasteboard 没有 expirationDate 属性（iOS 26 SDK 里它只是 OptionsKey 的一个键），
        // 过期只能走 setItems 的 options：系统级失效，App 被挂起后照样生效
        UIPasteboard.general.setItems(
            [["public.utf8-plain-text": s]],
            options: [.expirationDate: Date().addingTimeInterval(60)]
        )
    }
}

struct SecretsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [SecretEntry] = []
    @State private var loading = true
    @State private var showEdit = false
    @State private var editing: SecretEntry?
    @State private var toast = ""
    // Face ID / 生物识别解锁
    @State private var locked = true
    @State private var authFailed = false
    // v3.9.41（SR22）：明文只在有限时间内停留——每条已显形的密码挂一个自动掩码任务，
    // 离开前台时也一并掩掉（此前 reveal 后直到重进页面都是明文，任务切换器快照也能拍到）
    @State private var maskTasks: [String: Task<Void, Never>] = [:]
    @Environment(\.scenePhase) private var scenePhase
    private static let revealSeconds: TimeInterval = 30

    var body: some View {
        VStack(spacing: 0) {
            if locked {
                // 生物识别锁屏：验证通过才显示内容
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(Tint.subtle))
                            .frame(width: 76, height: 76)
                        Image(systemName: "faceid")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text("安全凭证存储库已锁定")
                        .font(.system(size: Typography.body, weight: .semibold))
                    Text("使用 Face ID 或设备密码解锁")
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.secondary)
                    if authFailed {
                        Text("验证失败，请重试")
                            .font(.system(size: Typography.subhead))
                            .foregroundStyle(.red)
                    }
                    Button {
                        authenticate()
                    } label: {
                        Text("解锁")
                            .font(.system(size: Typography.body, weight: .semibold))
                            .frame(minWidth: 120)
                            .pill(.primary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                // v3.9.23 豁免：这不是弹窗根底，是生物解锁「验证失败」态那一行的行内底
                // （同行有 .pill(.primary) 主按钮作为视觉主体），去掉会失去分隔感。
                .background(Color(uiColor: .systemBackground))
            } else {
                content
            }
        }
        .task {
            if locked { authenticate() }
        }
    }

    private var content: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if loading {
                    // v3.9.42：首屏骨架（左右留白与下方真列表同为 Spacing.xxl）
                    LoadingStateView(shape: .rows(3))
                } else if entries.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("未保存任何信息")
                            .font(.system(size: Typography.title, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("安全保存登录信息，供你管理 NAS、旁路由等设备。")
                            .font(.system(size: Typography.subhead))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                        Button {
                            editing = SecretEntry(id: "", name: "", type: "nas", address: "", username: "", hasPassword: false)
                            showEdit = true
                        } label: {
                            Text("添加登录信息")
                                .font(.system(size: Typography.body, weight: .semibold))
                                .pill(.primary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, Spacing.sm)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("登录信息使用服务端加密保存。解锁后可按需查看密码，离开页面后会自动遮蔽。")
                                .font(.system(size: Typography.subhead))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            VStack(spacing: 0) {
                                ForEach(entries.indices, id: \.self) { index in
                                    let entry = entries[index]
                                    SecretRow(entry: entry, onReveal: { reveal(entry) }, onEdit: { edit(entry) }, onDelete: { delete(entry) })
                                    if index < entries.count - 1 { MuseRowDivider() }
                                }
                            }
                            .background(Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.vertical, Spacing.lg)
                    }
                }
            }
        }
        // v3.9.23 决策：弹窗背景不覆盖，让系统默认玻璃生效（勿再挂实色底）。
        // 原来这里挂了一行 systemBackground 实色底 → 密钥页变实色页，与其它弹窗不统一。v4.0.x 移除。
        .task { await load() }
        // v3.9.41（SR22）：一离开前台就把已显形的密码全部掩回（任务切换器/切走再回来不再留明文）
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { maskAllPasswords() }
        }
        .sheet(isPresented: $showEdit) {
            SecretEditSheet(entry: editing, onSave: { newEntry in
                Task { await save(newEntry) }
            })
        }
        .overlay(alignment: .bottom) {
            if !toast.isEmpty {
                Text(toast)
                    .font(.system(size: Typography.subhead))
                    .padding(.horizontal, Spacing.section).padding(.vertical, Spacing.md)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.opacity)
            }
        }
        .navigationTitle("安全凭证存储库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = SecretEntry(id: "", name: "", type: "nas", address: "", username: "", hasPassword: false)
                    showEdit = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    /// Face ID 或设备密码验证；不可验证时保持锁定，绝不降级为明文访问。
    private func authenticate() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            authFailed = true
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: "验证后查看已加密保存的登录凭据") { success, _ in
            DispatchQueue.main.async {
                if success {
                    locked = false
                    authFailed = false
                } else {
                    authFailed = true
                }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let j = try await auth.json("/api/secrets")
            entries = (j["secrets"] as? [[String: Any]] ?? []).compactMap { d in
                guard let id = d["id"] as? String else { return nil }
                return SecretEntry(id: id,
                                   name: d["name"] as? String ?? "",
                                   type: d["type"] as? String ?? "other",
                                   address: d["address"] as? String ?? "",
                                   username: d["username"] as? String ?? "",
                                   hasPassword: (d["has_password"] as? Bool) ?? false)
            }
        } catch {
            toast = "加载失败：\(error.localizedDescription)"
        }
    }

    private func reveal(_ e: SecretEntry) {
        Task {
            do {
                let j = try await auth.json("/api/secrets/\(e.id)?reveal=true")
                let pw = j["password"] as? String ?? ""
                if let idx = entries.firstIndex(where: { $0.id == e.id }) {
                    entries[idx].password = pw
                }
                scheduleMask(e.id)
            } catch {
                toast = "获取失败"
            }
        }
    }

    /// v3.9.41（SR22）：显形倒计时（重复点击以最后一次为准）
    private func scheduleMask(_ id: String) {
        maskTasks[id]?.cancel()
        maskTasks[id] = Task {
            try? await Task.sleep(for: .seconds(SecretsView.revealSeconds))
            guard !Task.isCancelled else { return }
            maskTasks[id] = nil
            if let idx = entries.firstIndex(where: { $0.id == id }) {
                entries[idx].password = ""
            }
        }
    }

    /// 退后台/收起：全部掩掉，并撤掉未完成的倒计时
    private func maskAllPasswords() {
        for t in maskTasks.values { t.cancel() }
        maskTasks.removeAll()
        for idx in entries.indices where !entries[idx].password.isEmpty {
            entries[idx].password = ""
        }
    }

    private func edit(_ e: SecretEntry) {
        editing = e
        showEdit = true
    }

    private func delete(_ e: SecretEntry) {
        Task {
            // v2.0.102：仅服务器确认成功才移除（失败保留，重进不"复活"）
            if let j = try? await auth.json("/api/secrets/\(e.id)", method: "DELETE", body: nil),
               (j["ok"] as? Bool) == true {
                entries.removeAll { $0.id == e.id }
            } else {
                toast = "删除失败，请重试"
            }
        }
    }

    private func save(_ e: SecretEntry) async {
        do {
            var body: [String: Any] = [
                "name": e.name, "type": e.type, "address": e.address, "username": e.username
            ]
            if !e.id.isEmpty { body["id"] = e.id }
            if !e.password.isEmpty { body["password"] = e.password }
            let j = try await auth.json("/api/secrets", method: "POST", body: body)
            if (j["ok"] as? Bool) == true {
                toast = "已保存"
                await load()
            } else {
                toast = (j["error"] as? String) ?? "保存失败"
            }
        } catch {
            toast = "保存失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 单条凭据行（眼睛查看 / 复制 / 编辑 / 删除）

struct SecretRow: View {
    let entry: SecretEntry
    let onReveal: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var typeIcon: String {
        switch entry.type {
        case "nas": return "server.rack"
        case "router": return "wifi"
        default: return "key.fill"
        }
    }
    private var typeName: String {
        switch entry.type {
        case "nas": return "NAS"
        case "router": return "路由器"
        default: return "其他"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: typeIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
                    .frame(width: 34)
                Text(entry.name)
                    .font(.system(size: Typography.body, weight: .semibold))
                Text(typeName)
                    .font(.system(size: Typography.tiny))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xxs)
                    .background(Color.secondary.opacity(Tint.subtle), in: Capsule())
                Spacer()
                // 复制完整连接串
                Button {
                    SecretClipboard.copy("\(entry.username)@\(entry.address)")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                Button { onEdit() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            if !entry.address.isEmpty || !entry.username.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !entry.address.isEmpty { Label(entry.address, systemImage: "network") }
                    if !entry.username.isEmpty { Label(entry.username, systemImage: "person") }
                }
                .font(.system(size: Typography.caption))
                .foregroundStyle(.secondary)
            }
            // 密码：默认掩码，点击眼睛显示明文
            HStack(spacing: 8) {
                Text(entry.password.isEmpty ? "密码：••••••••" : "密码：\(entry.password)")
                    .font(.system(size: Typography.caption, design: .monospaced))
                    .foregroundStyle(entry.password.isEmpty ? .secondary : .primary)
                if entry.password.isEmpty {
                    Button {
                        onReveal()
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: Typography.subhead))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        SecretClipboard.copy(entry.password)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: Typography.subhead))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 新增/编辑表单

struct SecretEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: SecretEntry?
    let onSave: (SecretEntry) -> Void

    @State private var name = ""
    @State private var type = "nas"
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case address, name, username, password }
    private var isEditing: Bool { entry?.id.isEmpty == false }
    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let raw = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let host = URL(string: raw.contains("://") ? raw : "https://\(raw)")?.host,
              !host.isEmpty else { return raw }
        return host
    }
    private var canSave: Bool {
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!password.isEmpty || entry?.hasPassword == true)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                Spacer()
                Text(isEditing ? "编辑登录信息" : "添加登录信息")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("网站")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Menu {
                                Button("NAS") { type = "nas" }
                                Button("路由器") { type = "router" }
                                Button("其他") { type = "other" }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(typeLabel)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .font(.system(size: 14))
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                        VStack(spacing: 0) {
                            TextField("https://example.com", text: $address)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .address)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .name }
                                .padding(.horizontal, 18)
                                .frame(minHeight: 58)
                            Rectangle()
                                .fill(Color(uiColor: .separator).opacity(0.35))
                                .frame(height: 0.5)
                                .padding(.leading, 18)
                            TextField("名称（可选）", text: $name)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .username }
                                .padding(.horizontal, 18)
                                .frame(minHeight: 52)
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("登录信息")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 0) {
                            TextField("账号或邮箱", text: $username)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                .padding(.horizontal, 18)
                                .frame(minHeight: 60)
                            Rectangle()
                                .fill(Color(uiColor: .separator).opacity(0.35))
                                .frame(height: 0.5)
                                .padding(.leading, 18)
                            SecureField(entry?.hasPassword == true ? "密码（留空则保持不变）" : "密码", text: $password)
                                .textContentType(isEditing ? .newPassword : .password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                                .padding(.horizontal, 18)
                                .frame(minHeight: 60)
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    Button {
                        var value = entry ?? SecretEntry(id: "", name: "", type: "nas", address: "", username: "", hasPassword: false)
                        value.name = displayName
                        value.type = type
                        value.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
                        value.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !password.isEmpty { value.password = password }
                        onSave(value)
                        dismiss()
                    } label: {
                        Text(isEditing ? "保存" : "添加")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(canSave ? 1 : 0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(colors: canSave ? [Color(red: 0.17, green: 0.55, blue: 0.94), Color(red: 0.42, green: 0.36, blue: 0.88)] : [Color.gray.opacity(0.45), Color.gray.opacity(0.35)], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .padding(.top, 2)

                    Button("取消") { dismiss() }
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            if let entry {
                name = entry.name
                type = entry.type
                address = entry.address
                username = entry.username
            }
        }
    }

    private var typeLabel: String {
        switch type {
        case "nas": "NAS"
        case "router": "路由器"
        default: "其他"
        }
    }
}

// MARK: ===== 以下原为 Features/Settings/MCPSettingsSheet.swift =====

// MARK: - v3.5.0 MCP 工具服务管理
// App 配 key → 后端 /api/mcp/* → Hermes config.yaml → 本地模式聊天自动获得 MCP 工具
// 交互照 CustomProviderEditSheet（模板选择 + key 输入 + 列表管理）

struct MCPServerItem: Identifiable {
    let id: String          // name
    let url: String         // 已脱敏
    let hasKey: Bool
    let enabled: Bool
}

struct MCPTemplate: Identifiable {
    let id: String
    let name: String
    let desc: String
    let urlTemplate: String
    let keyHint: String
}

struct MCPSettingsSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var servers: [MCPServerItem] = []
    @State private var templates: [MCPTemplate] = []
    @State private var loading = false
    @State private var errMsg: String?

    // 新增表单
    @State private var showAdd = false
    @State private var customURL = ""
    @State private var key = ""
    @State private var saving = false
    // v3.9.41（SR25）：saveMsg 全仓无渲染点 → 保存成功/失败用户都看不到回执。
    // 改成列表顶部可见的 feedback 行（errMsg 会把整个列表换掉，不能拿来当回执）。
    @State private var feedback: String?
    // v3.5.0 review：删除走二次确认（服务删除会触发 hermes 重启，防误触）
    @State private var pendingDelete: MCPServerItem?

    var body: some View {
        NavigationStack {
            Form {
                // v3.9.41（SR25）：保存/删除回执（原来写进 saveMsg 却无人渲染）
                if let f = feedback {
                    Section {
                        Text(f).font(.system(size: Typography.subhead))
                            .foregroundStyle(f.hasPrefix("❌") ? Color.red : Color.green)
                    }
                }
                if loading {
                    // v3.9.42：首屏骨架；Form 已自带缩进，horizontalPadding 传 0 免得二次内缩
                    Section { LoadingStateView(shape: .rows(2), horizontalPadding: 0) }
                } else if let errMsg {
                    Section {
                        Text("⚠️ \(errMsg)").font(.system(size: Typography.subhead)).foregroundStyle(.orange)
                    }
                } else {
                    serverListSection
                    addSection
                    hintSection
                }
            }
            .navigationTitle("工具服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                // v3.9.41（SR25）：保存改成「等结果再关」——失败时表单留在屏上，输入不丢
                MCPAddSheet(templates: templates) { template, k, url in
                    await save(template: template, key: k, url: url)
                }
                .scrollContentBackground(.hidden)
            }
            .confirmationDialog("删除 \(pendingDelete?.id ?? "")？将触发 Hermes 重启（约 30 秒）",
                                isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let s = pendingDelete { Task { await delete(s.id) } }
                    pendingDelete = nil
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            }
            .task { await load() }
        }
    }

    // MARK: 已配置服务列表
    @ViewBuilder private var serverListSection: some View {
        Section("已启用（\(servers.count)）") {
            if servers.isEmpty {
                Text("暂无——点右上角 + 添加，如高德地图（天气/路线/导航）")
                    .font(.system(size: Typography.subhead))
                    .foregroundStyle(.tertiary)
            }
            ForEach(servers) { s in
                HStack(spacing: 10) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: Typography.subhead, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: Radius.icon, style: .continuous))
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(s.id).font(.system(size: Typography.body, weight: .medium))
                        Text(s.enabled ? "已启用" : "已停用")
                            .font(.system(size: Typography.caption))
                            .foregroundStyle(s.enabled ? Color.green : Color.secondary)
                    }
                    Spacer()
                    // 删除（二次确认走 confirmationDialog）
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDelete = s
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder private var addSection: some View {
        Section("添加") {
            Button {
                showAdd = true
            } label: {
                Label("从模板添加（推荐）", systemImage: "plus.circle.fill")
            }
        }
    }

    @ViewBuilder private var hintSection: some View {
        Section {
            Text("保存后 Hermes 自动重启（约 30 秒），之后在「聊天」里直接说\"帮我查明天天气\"即可触发工具。删除同理。")
                .font(.system(size: Typography.caption))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: 网络
    private func load() async {
        loading = true
        errMsg = nil
        defer { loading = false }
        do {
            let d = try await auth.json("/api/mcp/servers")
            guard let ok = d["ok"] as? Bool, ok else {
                errMsg = "加载失败"
                return
            }
            var arr: [MCPServerItem] = []
            if let sv = d["servers"] as? [String: Any] {
                for (name, e) in sv {
                    let url = e as? [String: Any] ?? [:]
                    arr.append(MCPServerItem(
                        id: name,
                        url: url["url"] as? String ?? "",
                        hasKey: url["has_key"] as? Bool ?? false,
                        enabled: url["enabled"] as? Bool ?? true))
                }
            }
            servers = arr.sorted { $0.id < $1.id }
            var tps: [MCPTemplate] = []
            if let ts = d["templates"] as? [[String: Any]] {
                for t in ts {
                    tps.append(MCPTemplate(
                        id: t["id"] as? String ?? "",
                        name: t["name"] as? String ?? "",
                        desc: t["desc"] as? String ?? "",
                        urlTemplate: t["url_template"] as? String ?? "",
                        keyHint: t["key_hint"] as? String ?? ""))
                }
            }
            templates = tps
        } catch {
            errMsg = "加载失败：\(error.localizedDescription)"
        }
    }

    /// v3.9.41（SR25）：返回是否保存成功，供添加表单决定「关窗」还是「留在屏上重试」
    private func save(template: MCPTemplate?, key k: String, url: String) async -> Bool {
        saving = true
        defer { saving = false }
        do {
            var body: [String: Any] = ["name": template?.id ?? "custom"]
            if let template {
                body["template"] = template.id
                body["key"] = k
            } else {
                body["url"] = url
            }
            let d = try await auth.json("/api/mcp/save", method: "POST", body: body)
            guard (d["ok"] as? Bool) ?? false else {
                feedback = "❌ \(d["error"] as? String ?? "保存失败")"
                return false
            }
            feedback = "✅ 已保存，约 30 秒后生效"
            await load()
            return true
        } catch {
            feedback = "❌ \(error.localizedDescription)"
            return false
        }
    }

    // v3.9.41（SR24）：删除成功只刷新、不校验 ok:false（400/404 走 catch，但 200+ok:false 被当成功）
    private func delete(_ name: String) async {
        do {
            let d = try await auth.json("/api/mcp/delete", method: "POST", body: ["name": name])
            guard (d["ok"] as? Bool) ?? false else {
                feedback = "❌ 删除失败：\(d["error"] as? String ?? "服务器拒绝")"
                return
            }
            feedback = "✅ 已删除 \(name)，约 30 秒后生效"
            await load()
        } catch {
            feedback = "❌ 删除失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 新增 sheet（模板选择 + key）
struct MCPAddSheet: View {
    let templates: [MCPTemplate]
    /// v3.9.41（SR25）：改为 async 并回传是否成功——失败时表单不关，Key/URL 不丢
    let onSaved: (MCPTemplate?, String, String) async -> Bool
    @Environment(\.dismiss) private var dismiss

    @State private var picked: MCPTemplate?
    @State private var customURL = ""
    @State private var key = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("选择服务") {
                    ForEach(templates) { t in
                        Button {
                            picked = t
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).font(.system(size: Typography.body, weight: .medium)).foregroundColor(.primary)
                                    Text(t.desc).font(.system(size: Typography.caption)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if picked?.id == t.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    // 高级：自定义 URL
                    Button {
                        picked = nil
                    } label: {
                        HStack {
                            Text("自定义 URL（高级）").font(.system(size: Typography.body)).foregroundColor(.primary)
                            Spacer()
                            if picked == nil && !customURL.isEmpty {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                    if picked == nil {
                        TextField("https://...（工具服务地址）", text: $customURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: Typography.subhead))
                    }
                }
                if let t = picked {
                    Section("Key") {
                        SecureField(t.keyHint, text: $key)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
            }
            .navigationTitle("添加工具服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "保存中…" : "保存") {
                        guard !saving else { return }
                        Task {
                            saving = true
                            let ok = await onSaved(picked, key, customURL)
                            saving = false
                            if ok { dismiss() }   // v3.9.41（SR25）：失败不关窗，父层列表已给回执
                        }
                    }
                    .disabled(!canSave || saving)
                }
            }
        }
    }

    private var canSave: Bool {
        if let t = picked { return !key.isEmpty }
        return customURL.hasPrefix("https://") || customURL.hasPrefix("http://")
    }
}

// MARK: ===== 以下原为 Features/Settings/HASettingsSheet.swift =====

// MARK: - HA 设置（Home Assistant 地址 + Token，联动看板智能家居卡片）

struct HASettingsSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var address = ""
    @State private var token = ""
    @State private var hasToken = false
    @State private var saving = false
    @State private var toast = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Home Assistant 连接配置，保存后看板「智能家居」卡片自动使用新配置")
                .font(.system(size: Typography.caption))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("HA 地址")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                TextField("如 http://ha.example.com:8123", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("长期访问 Token")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                SecureField(hasToken ? "已配置（输入新值可替换）" : "粘贴 HA 长期访问令牌", text: $token)
                    .textFieldStyle(.roundedBorder)
                if hasToken && token.isEmpty {
                    Text("当前已有 Token，留空保持不变")
                        .font(.system(size: Typography.tiny))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                save()
            } label: {
                HStack {
                    Spacer()
                    if saving { ProgressView() }
                    else { Text("保存") }
                    Spacer()
                }
                .font(.system(size: Typography.body, weight: .semibold))
                .frame(maxWidth: .infinity)
                .pill(.primary)
            }
            .buttonStyle(.plain)
            .disabled(saving || address.isEmpty)

            if !toast.isEmpty {
                Text(toast)
                    .font(.system(size: Typography.subhead))
                    .foregroundStyle(toast.hasPrefix("✅") ? .green : .red)
            }

            Spacer()
        }
        .padding(Spacing.sheetInset)
        .navigationTitle("HA 设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") { dismiss() }
            }
        }
        .task {
            if let j = try? await auth.json("/api/ha/config") {
                address = j["address"] as? String ?? ""
                hasToken = (j["has_token"] as? Bool) ?? false
            }
        }
        }
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            var body: [String: Any] = ["address": address]
            if !token.isEmpty { body["token"] = token }
            do {
                let j = try await auth.json("/api/ha/config", method: "POST", body: body)
                if (j["ok"] as? Bool) == true {
                    toast = "✅ 已保存，看板智能家居卡片已联动"
                    if !token.isEmpty { token = ""; hasToken = true }
                } else {
                    toast = "保存失败：\((j["error"] as? String) ?? "未知错误")"
                }
            } catch {
                toast = "保存失败：\(error.localizedDescription)"
            }
        }
    }
}


// MARK: - J 线 2026-10-06：Hermes 模型选择器（原「模型管理」独立页迁入「连接设置」）
// v4.4.x 多服务商：GET /api/hermes/models → {providers: [{id,name,models,error}]}；
// POST /api/hermes/model {provider, model_id} → 切换；POST /hermes/models/hide → 隐藏。

struct HermesModelOption: Identifiable {
    let id: String
    let name: String
    let selected: Bool

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, !id.isEmpty else { return nil }
        self.id = id
        self.name = (json["name"] as? String) ?? id
        self.selected = (json["selected"] as? Bool) ?? false
    }
}

struct HermesProviderGroup: Identifiable {
    let id: String
    let name: String
    var models: [HermesModelOption]
    let error: String?

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, !id.isEmpty else { return nil }
        self.id = id
        self.name = (json["name"] as? String) ?? id
        self.models = ((json["models"] as? [[String: Any]]) ?? [])
            .compactMap(HermesModelOption.init(json:))
        self.error = json["error"] as? String
    }
}

struct HermesProviderInfo: Identifiable {
    let id: String
    let name: String
    let hasKey: Bool
    let isDefault: Bool
    let editable: Bool

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, !id.isEmpty else { return nil }
        self.id = id
        self.name = (json["name"] as? String) ?? id
        self.hasKey = (json["has_key"] as? Bool) ?? false
        self.isDefault = (json["is_default"] as? Bool) ?? false
        self.editable = (json["editable"] as? Bool) ?? false
    }
}

struct HermesModelPickerSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var groups: [HermesProviderGroup] = []
    @State private var loading = true
    @State private var loadError = false
    @State private var busyID: String? = nil
    @State private var showProviderManage = false
    @State private var hideConfirm: (provider: String, model: HermesModelOption)? = nil

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loadError {
                    VStack(spacing: 10) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("未能获取模型列表")
                            .font(.system(size: 17, weight: .medium))
                        Text("检查 Hermes 连接后重试")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                        Button("重试") {
                            Haptics.tap()
                            Task { await load() }
                        }
                        .font(.system(size: 15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groups.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "cpu")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("暂无可用模型")
                            .font(.system(size: 17, weight: .medium))
                        Text("Hermes 服务未返回模型列表")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groups) { g in
                            NavigationLink {
                                HermesModelListView(
                                    provider: g,
                                    busyID: $busyID,
                                    onSelect: { m in Task { await select(provider: g.id, m) } },
                                    onHide: { m in hideConfirm = (g.id, m) }
                                )
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(g.name)
                                            .font(.system(size: 17))
                                            .foregroundStyle(.primary)
                                        Text("\(g.models.count) 个模型")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    if g.models.contains(where: { $0.selected }) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("选择模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        Haptics.tap()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptics.tap()
                        showProviderManage = true
                    } label: {
                        Image(systemName: "server.rack")
                    }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showProviderManage) {
                HermesProviderManageView()
            }
            .confirmationDialog(
                "隐藏模型", isPresented: Binding(
                    get: { hideConfirm != nil },
                    set: { if !$0 { hideConfirm = nil } }),
                titleVisibility: .visible
            ) {
                Button("隐藏", role: .destructive) {
                    if let hc = hideConfirm {
                        Task { await hideModel(provider: hc.provider, hc.model) }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let hc = hideConfirm {
                    Text("以后可在服务商管理里恢复「\(hc.model.name)」")
                }
            }
        }
    }

    private func load() async {
        loading = true
        loadError = false
        defer { loading = false }
        // 2026-10-07：用 Hermes 真实配置（/api/agent/hermes/inspect/models），
        // 不再用上游服务商列表（那是 DeepSeek-V4 这类，和 Hermes 实际用的不是一份）
        guard let j = try? await auth.json("/api/agent/hermes/inspect/models"),
              let arr = j["models"] as? [[String: Any]] else {
            loadError = true
            return
        }
        // 按 provider 分组，转成 UI 要的格式
        var groups: [String: [[String: Any]]] = [:]
        for m in arr {
            let p = (m["provider"] as? String) ?? "hermes"
            groups[p, default: []].append(m)
        }
        self.groups = groups.map { pid, models in
            HermesProviderGroup(json: ["id": pid, "name": pid, "models": models])
        }.compactMap { $0 }
    }

    private func select(provider pid: String, _ m: HermesModelOption) async {
        let key = "\(pid)|\(m.id)"
        guard busyID == nil else { return }
        busyID = key
        defer { busyID = nil }
        guard let j = try? await auth.json("/api/agent/hermes/model", method: "POST",
                                           body: ["provider": pid, "model_id": m.id]),
              (j["ok"] as? Bool) == true else { return }
        // v4.4.x：只认后端 selected，不再写 UserDefaults
        await load()
    }

    private func hideModel(provider pid: String, _ m: HermesModelOption) async {
        hideConfirm = nil
        // 黑名单本地累积后整体上报（后端 save_hidden_models 为整体替换语义）
        var hidden = Set(UserDefaults.standard.stringArray(forKey: "ql_hidden_\(pid)") ?? [])
        hidden.insert(m.id)
        let arr = Array(hidden)
        UserDefaults.standard.set(arr, forKey: "ql_hidden_\(pid)")
        _ = try? await auth.json("/api/agent/hermes/models/hide", method: "POST",
                                 body: ["provider": pid, "model_ids": arr])
        await load()
    }
}

// MARK: - 服务商的模型列表（两级选择第二级）

struct HermesModelListView: View {
    let provider: HermesProviderGroup
    @Binding var busyID: String?
    let onSelect: (HermesModelOption) -> Void
    let onHide: (HermesModelOption) -> Void

    var body: some View {
        List {
            if let err = provider.error {
                Text(err)
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
            }
            ForEach(provider.models) { m in
                Button {
                    Haptics.tap()
                    onSelect(m)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name)
                                .font(.system(size: 17))
                                .foregroundStyle(.primary)
                            if m.name != m.id {
                                Text(m.id)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if busyID == "\(provider.id)|\(m.id)" {
                            ProgressView().controlSize(.small)
                        } else if m.selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        onHide(m)
                    } label: {
                        Label("隐藏此模型", systemImage: "eye.slash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(provider.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 服务商管理

struct HermesProviderManageView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var providers: [HermesProviderInfo] = []
    @State private var loading = true
    @State private var showAdd = false
    @State private var deleteTarget: HermesProviderInfo? = nil
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(providers) { p in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name)
                                        .font(.system(size: 17))
                                        .foregroundStyle(.primary)
                                    Text(p.isDefault ? "默认服务商" : (p.hasKey ? "已配置密钥" : "未配置密钥"))
                                        .font(.system(size: 13))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                if !p.editable {
                                    Text("只读")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if p.editable {
                                    Button(role: .destructive) {
                                        deleteTarget = p
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        if !message.isEmpty {
                            Text(message)
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("服务商")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showAdd) {
                HermesProviderAddView(onDone: { Task { await load() } })
            }
            .confirmationDialog("删除服务商", isPresented: Binding(
                get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let t = deleteTarget { Task { await remove(t) } }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("该服务商的模型选择与隐藏名单将一并清除")
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let j = try? await auth.json("/api/agent/hermes/providers"),
              let arr = j["providers"] as? [[String: Any]] else { return }
        providers = arr.compactMap(HermesProviderInfo.init(json:))
    }

    private func remove(_ p: HermesProviderInfo) async {
        deleteTarget = nil
        guard let j = try? await auth.json("/api/agent/hermes/providers/\(p.id)",
                                           method: "DELETE"),
              (j["ok"] as? Bool) == true else {
            message = "删除失败"
            return
        }
        await load()
    }
}

struct HermesProviderAddView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    var onDone: () -> Void = {}

    @State private var name = ""
    @State private var url = ""
    @State private var key = ""
    @State private var saving = false
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（如 DeepSeek）", text: $name)
                    TextField("地址（如 http://192.168.1.5:8642）", text: $url)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("API Key", text: $key)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } footer: {
                    Text("保存前会自动测试连通性，连不通不会保存。")
                }
                if !message.isEmpty {
                    Section {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("新增服务商")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "保存中…" : "保存") {
                        Task { await save() }
                    }
                    .disabled(saving || url.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        message = ""
        guard let j = try? await auth.json("/api/agent/hermes/providers", method: "POST",
                                           body: ["name": name, "url": url, "key": key]),
              let ok = j["ok"] as? Bool else {
            message = "网络错误"
            return
        }
        if ok {
            onDone()
            dismiss()
        } else {
            message = (j["error"] as? String) ?? "保存失败"
        }
    }
}
