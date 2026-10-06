import SwiftUI

// MARK: - 灰度重做 2026-10-06 晚：侧边栏「历史对话」数据
//
// 原「旁聊」占位 → 真实会话历史（用户硬性要求 4）。
// 调 /api/sessions/list（与 SessionsView.load 同一口径：ChatSession.parse + 按 lastTime 倒序），
// 取最近 8 条。侧边栏打开时触发一次加载（DockTabView 的 onChange(of: sidebarOpen)），
// 3 秒内不重复拉；未登录 / 拉取失败诚实留空，不弹错误。
@Observable
final class SidebarHistoryStore {
    var sessions: [ChatSession] = []
    var isLoading = false
    private var lastLoadAt: Date?

    @MainActor
    func refreshIfNeeded(auth: AuthStore) async {
        if let last = lastLoadAt, Date().timeIntervalSince(last) < 3 { return }
        guard auth.isLoggedIn else { return }
        lastLoadAt = Date()
        isLoading = true
        defer { isLoading = false }
        do {
            let j = try await auth.json("/api/sessions/list")
            let raw = j["sessions"] as? [Any] ?? []
            sessions = Array(raw.compactMap { ChatSession.parse($0 as? [String: Any] ?? [:]) }
                .sorted { ($0.lastTime ?? 0) > ($1.lastTime ?? 0) }
                .prefix(8))
        } catch {
            // 诚实留空：侧边栏里不展开错误态
        }
    }

    /// v4.4：改名/删除后强制刷新（绕开 3 秒节流）
    @MainActor
    func refreshNow(auth: AuthStore) async {
        lastLoadAt = nil
        await refreshIfNeeded(auth: auth)
    }
}

// MARK: - 侧边栏开关通知（聊天页顶栏按钮 → DockTabView）

extension Notification.Name {
    static let qingliaoToggleSidebar = Notification.Name("qingliao_toggle_sidebar")
    /// 打开会话搜索（聊天页顶栏搜索按钮 → DockTabView 弹出 SessionsView sheet）
    static let qingliaoOpenChatSearch = Notification.Name("qingliao_open_chat_search")
    /// 打开任务中心（侧边栏「工具」→ ChatView 全屏页）
    static let qingliaoOpenTaskCenter = Notification.Name("qingliao_open_task_center")
}

// MARK: - 灰度重做 2026-10-06 晚：Muse 风格侧边栏（用户硬性要求 2）
//
// 对标 Muse app 侧边栏参考图：
// 顶部 App 名 + 设置齿轮（圆形按钮）→ 设置页唯一入口；
// 「选项卡」分组：5 tab（对话/资讯/点子/目标/看板），极简线条图标 + 文字，选中灰胶囊；
// 「历史对话」分组：最近 8 条会话（标题 + 相对时间），点一行进聊天页打开该会话；
// 底部：搜索框 + 新建按钮。干净、克制、无彩色。
//
// 打开方式：聊天页顶栏 sidebar.left 按钮 / 左边缘右滑。
// 关闭：点遮罩 / 左滑 / 再点按钮。

/// 侧边栏抽屉（盖在 DockTabView 最上层，由宿主控制 isOpen）
struct QingliaoSidebar: View {
    @Binding var isOpen: Bool
    @Binding var selectedTab: DockTab
    var history: SidebarHistoryStore
    var onOpenSettings: () -> Void
    var onNewChat: () -> Void
    var onSearch: () -> Void
    /// 点历史会话 → 宿主切到聊天页并打开该会话（DockTabView：selected = .chat; chat.load(session)）
    var onOpenSession: (ChatSession) -> Void

    @Environment(AuthStore.self) private var auth
    // v4.4：历史会话长按菜单（置顶/重命名/删除）——置顶 key 与 SessionsView 同源
    @State private var pinnedIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "qingliao_pinned_sessions") ?? [])
    @State private var renameTarget: ChatSession?
    @State private var renameText = ""
    @State private var confirmDelete: ChatSession?
    @State private var opError: String?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 遮罩：点按关闭
                if isOpen {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { close() }
                        .transition(.opacity)
                }
                // 侧边栏面板
                if isOpen {
                    sidebarPanel
                        .frame(width: min(geo.size.width * 0.82, 340))
                        .transition(.move(edge: .leading))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isOpen)
        }
        .ignoresSafeArea()
    }

    private func close() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isOpen = false
        }
    }

    private var sidebarPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：App 名 + 设置齿轮（设置页唯一入口）
            HStack {
                Text("Nori")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    Haptics.tap()
                    close()
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .a11yGlass(.regular, in: Circle(), stroke: Color.primary.opacity(0.08))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 60)
            .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 选项卡分组
                    Text("选项卡")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 28)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    ForEach(DockTab.allCases) { tab in
                        sidebarTabRow(tab)
                    }

                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                    // 工具分组：任务中心（原顶栏药丸按钮已干掉，迁入此处）
                    Text("工具")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    Button {
                        close()
                        NotificationCenter.default.post(name: .qingliaoOpenTaskCenter, object: nil)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "list.bullet.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(.primary)
                                .frame(width: 28)
                            Text("任务中心")
                                .font(.system(size: 17))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                    // 历史对话分组（原「旁聊」占位 → 真实会话历史；无头像、灰度）
                    Text("历史对话")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    if history.sessions.isEmpty {
                        Text(history.isLoading ? "加载中…" : "还没有对话")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                    } else {
                        ForEach(sortedSessions) { session in
                            historyRow(session)
                        }
                    }
                }
            }

            Spacer()

            // 底部：搜索框 + 新建按钮
            HStack(spacing: 12) {
                Button {
                    Haptics.tap()
                    close()
                    onSearch()
                } label: {
                    HStack {
                        Text("搜索")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .a11yGlass(.regular, in: Capsule(), stroke: Color.primary.opacity(0.08))
                }
                .buttonStyle(.plain)
                Button {
                    Haptics.tap()
                    close()
                    onNewChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                        .frame(width: 52, height: 52)
                        .a11yGlass(.regular, in: Circle(), stroke: Color.primary.opacity(0.08))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .frame(maxHeight: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.trailing, 60)   // 右侧露出一点底页，暗示可滑回
        .shadow(color: .black.opacity(0.15), radius: 24, x: 8, y: 0)
        // v4.4：历史会话长按菜单的改名/删除/失败提示
        .alert("重命名会话", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField("会话名称", text: $renameText)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("确定") { doRename() }
        }
        .alert("删除会话", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("取消", role: .cancel) { confirmDelete = nil }
            Button("删除", role: .destructive) {
                if let s = confirmDelete { confirmDelete = nil; doDelete(s) }
            }
        } message: {
            Text("将删除「\(confirmDelete?.title ?? "")」及其全部消息，此操作不可恢复")
        }
        .alert("操作失败", isPresented: Binding(get: { opError != nil }, set: { if !$0 { opError = nil } })) {
            Button("好", role: .cancel) { opError = nil }
        } message: {
            Text(opError ?? "")
        }
    }

    /// 选项卡行：线条图标 + 文字；选中 = 灰胶囊底
    private func sidebarTabRow(_ tab: DockTab) -> some View {
        let isSelected = (tab == selectedTab)
        return Button {
            selectedTab = tab
            close()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
                    .frame(width: 28)
                Text(tab.title)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color(.systemGray5) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .padding(.horizontal, 12)
            .contentShape(Rectangle())   // v4.4：整行都是热区（含胶囊外 12pt 边距），点行缝也有反应
        }
        .buttonStyle(.plain)
    }

    /// v4.4：置顶优先 + 按时间倒序（置顶 key 与 SessionsView 同源）
    private var sortedSessions: [ChatSession] {
        history.sessions.sorted {
            let p0 = pinnedIDs.contains($0.id) ? 0 : 1
            let p1 = pinnedIDs.contains($1.id) ? 0 : 1
            if p0 != p1 { return p0 < p1 }
            return ($0.lastTime ?? 0) > ($1.lastTime ?? 0)
        }
    }

    private func isFixedSession(_ id: String) -> Bool {
        id == ChatStore.deliverySessionId || id == ChatStore.proactiveSessionId
    }

    /// 历史会话行：点按打开；长按菜单（置顶/重命名/删除，对标 SessionsView）
    private func historyRow(_ session: ChatSession) -> some View {
        Button {
            close()
            onOpenSession(session)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if pinnedIDs.contains(session.id) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    Text(session.title.isEmpty ? "新对话" : session.title)
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                if !session.relativeTime.isEmpty {
                    Text(session.relativeTime)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)   // v4.4：10→12，热区 ≥44pt
            .contentShape(Rectangle())   // v4.4：整行热区
        }
        .buttonStyle(.plain)
        .contextMenu {
            // 固定会话（投递/主动）不给操作入口：点了后端也会拒绝
            if !isFixedSession(session.id) {
                Button {
                    togglePin(session)
                } label: {
                    Label(pinnedIDs.contains(session.id) ? "取消置顶" : "置顶",
                          systemImage: pinnedIDs.contains(session.id) ? "pin.slash" : "pin")
                }
                Button {
                    renameTarget = session
                    renameText = session.title
                } label: {
                    Label("重命名", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    confirmDelete = session
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    private func togglePin(_ s: ChatSession) {
        if pinnedIDs.contains(s.id) {
            pinnedIDs.remove(s.id)
        } else {
            pinnedIDs.insert(s.id)
        }
        UserDefaults.standard.set(Array(pinnedIDs), forKey: "qingliao_pinned_sessions")
        Haptics.tap()
    }

    /// v4.4：侧边栏改名——走 /api/sessions/merge 整会话覆盖（App 不发 updatedAt，后端恒判 incoming 赢）；
    /// 必须带上原 messages，否则整会话被只有 id+title 的空壳覆盖（merge 是整行替换）。
    private func doRename() {
        guard let t = renameTarget else { return }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        renameTarget = nil
        guard !newName.isEmpty, newName != t.title else { return }
        Task {
            do {
                let j = try await auth.json("/api/sessions/merge", method: "POST", body: [
                    "sessions": [["id": t.id, "title": newName,
                                  "messages": ChatStore.messagesPayload(t.messages)] as [String: Any]],
                    "deleted": [] as [Any]
                ])
                if (j["ok"] as? Bool) == true {
                    Haptics.success()
                } else {
                    opError = "改名未同步到服务器，请检查网络后重试"
                }
                await history.refreshNow(auth: auth)
            } catch {
                opError = "改名未同步到服务器：\(error.localizedDescription)"
                await history.refreshNow(auth: auth)
            }
        }
    }

    private func doDelete(_ s: ChatSession) {
        Task {
            do {
                let j = try await auth.json("/api/sessions/merge", method: "POST", body: [
                    "sessions": [] as [Any],
                    "deleted": [s.id]
                ])
                if (j["ok"] as? Bool) == true {
                    Haptics.success()
                } else {
                    opError = "删除未同步到服务器，请检查网络后重试"
                }
                await history.refreshNow(auth: auth)
            } catch {
                opError = "删除未同步到服务器：\(error.localizedDescription)"
                await history.refreshNow(auth: auth)
            }
        }
    }
}
