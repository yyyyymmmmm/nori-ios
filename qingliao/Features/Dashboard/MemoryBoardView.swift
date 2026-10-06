import SwiftUI

// MARK: - 记忆一级入口（看板大卡 + 记忆二级页）
//
// 对标 Muse 记忆 tab：Hero（统计）+ 文件夹网格 + 底部快捷输入。
//
// 数据源（与设置页「AI 记忆」同一份，不造新后端）：
//   · 列表 GET /api/memory/list → MemoryEntry.parse（items 优先、缺失回落 entries）
//   · 新增 POST /api/memory/add {"text":}
//   · 编辑 / 删除 / 改状态沿用设置页 MemoryView（管理弹窗），本页只做浏览 + 快记。
// 分组口径：复用 MemoryEntry.source —— manual=手动添加 / chat=聊天中自动记住 / 其他。
// App 侧没有独立的「分类」字段，不造新口径。
// 健康小格：现有 HealthStore 只暴露给 Agent 读的文本 summary（睡眠/步数/心率是一句中文文案），
// 没有结构化数值；从文案里抠数字不可靠 —— 按既定口径只做记忆统计，不造新后端。
// 旧入口：设置页「AI 记忆」行仍进 MemoryView（管理：编辑/删除/改状态）；
// 「Agent 记忆」是另一套后端（/api/agent/rules 路由规则），与本页无重叠；两者都保留。

// MARK: - 看板用的记忆大卡（自包含：自己取数、无外部传参）
//
// coordinator 接入方式：在看板 Hero 下方直接放 `MemoryHeroCard()` 即可。
// 点卡 → 本卡自己弹 MemoryBoardView（sheet），不需要外部传导航状态。

struct MemoryHeroCard: View {
    @Environment(AuthStore.self) private var auth
    @State private var items: [MemoryEntry] = []
    @State private var loaded = false
    @State private var showBoard = false

    var body: some View {
        Button {
            showBoard = true
        } label: {
            HStack(spacing: Spacing.xl) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .background(Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Radius.inset))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("记忆")
                            .font(.system(size: Typography.title, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Text(countText)
                            .font(.system(size: Typography.subhead))
                            .foregroundStyle(.secondary)
                    }
                    Text(latestText)
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashboardCard(cornerRadius: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("记忆，\(countText)，\(latestText)")
        .accessibilityHint("打开记忆页")
        .sheet(isPresented: $showBoard) {
            MemoryBoardView()
        }
        .task { await load() }
        .onChange(of: showBoard) { _, presented in
            // 从二级页回来（可能刚记了一句）→ 刷新条数与最新一条
            if !presented { Task { await refresh() } }
        }
    }

    private var countText: String {
        loaded ? "\(items.count) 条" : "加载中…"
    }

    private var latestText: String {
        guard loaded else { return "正在加载记忆…" }
        guard let e = latest else { return "还没有记忆，点一下记一句" }
        return e.text
    }

    /// 「最近一条」：按展示日期（更新时间优先）倒排；老条目无日期时沉底，取第一条兜底。
    private var latest: MemoryEntry? {
        items.sorted { ($0.displayDate ?? .distantPast) > ($1.displayDate ?? .distantPast) }.first
    }

    private func load() async {
        guard !loaded else { return }
        loaded = true
        await refresh()
    }

    private func refresh() async {
        guard let j = await auth.jsonOrLog("/api/memory/list") else { return }
        let parsed = MemoryEntry.parse(j)
        // 与设置页 MemoryView 同一口径：解析不出东西保持原列表；
        // 后端真返回空列表（字段在）才清空，避免删光后残留幽灵条目。
        if parsed.isEmpty && !items.isEmpty && !MemoryEntry.hasListField(j) { return }
        items = parsed
    }
}

// MARK: - 记忆二级页

struct MemoryBoardView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var items: [MemoryEntry] = []
    @State private var loaded = false
    /// 文件夹筛选：nil = 全部；否则为分组 key（manual / chat / other）
    @State private var filterKey: String?
    @State private var newText = ""
    @State private var busy = false
    @State private var toast: String?
    @State private var showManage = false
    @State private var viewing: MemoryEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    folderSection
                    entrySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .refreshable { await refresh() }
            .safeAreaInset(edge: .bottom) { quickInputBar }
            .navigationTitle("记忆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("管理") { showManage = true }
                        .accessibilityHint("编辑、删除或修改记忆状态")
                }
            }
            .sheet(isPresented: $showManage) {
                // 编辑 / 删除 / 改状态沿用设置页已有管理能力，不在本页再造一套
                MemoryView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $viewing) { entry in
                MemoryEntryDetailSheet(entry: entry)
                    .presentationDetents([.medium])
            }
            .overlay(alignment: .bottom) { toastPill }
            .task { await load() }
        }
    }

    // MARK: Hero：记忆统计

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记忆统计")
                .font(.system(size: Typography.subhead, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                statCell(value: "\(items.count)", label: "总条目")
                Divider().padding(.vertical, 4)
                statCell(value: "\(weekAdded)", label: "本周新增")
            }
            .padding(.vertical, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(cornerRadius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("记忆统计，总条目 \(items.count)，本周新增 \(weekAdded)")
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: Typography.titleXL, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: Typography.caption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 本周新增：按 created 落在本周的条目；老条目无 created（App 不编假日期）→ 不计入。
    private var weekAdded: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let start = cal.date(from: comps) else { return 0 }
        return items.filter { ($0.created ?? .distantPast) >= start }.count
    }

    // MARK: 文件夹网格（分组口径复用 MemoryEntry.source）

    private struct MemoryGroup: Identifiable {
        let key: String
        let name: String
        let icon: String
        let count: Int
        var id: String { key }
    }

    private static func groupKey(_ e: MemoryEntry) -> String {
        switch e.source {
        case "manual": return "manual"
        case "chat": return "chat"
        default: return "other"
        }
    }

    private var groups: [MemoryGroup] {
        let counts = Dictionary(grouping: items, by: Self.groupKey)
        return [
            ("manual", "手动添加", "hand.tap"),
            ("chat", "聊天中自动记住", "bubble.left.and.bubble.right"),
            ("other", "其他", "tray"),
        ].compactMap { key, name, icon in
            let c = counts[key]?.count ?? 0
            return c > 0 ? MemoryGroup(key: key, name: name, icon: icon, count: c) : nil
        }
    }

    private func groupName(_ key: String) -> String? {
        groups.first(where: { $0.key == key })?.name
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分组")
                .font(.system(size: Typography.subhead, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
            if !groups.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(groups) { g in folderCard(g) }
                }
            }
        }
    }

    private func folderCard(_ g: MemoryGroup) -> some View {
        let selected = filterKey == g.key
        return Button {
            filterKey = selected ? nil : g.key
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(g.name)
                    .font(.system(size: Typography.subhead, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(g.count) 项")
                    .font(.system(size: Typography.caption))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .systemBackground),
                        in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.18),
                            lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(g.name)，\(g.count) 项\(selected ? "，已筛选" : "")")
        .accessibilityHint("轻点按此分组筛选，再点一次取消")
    }

    // MARK: 条目列表（只读浏览；查看走详情弹窗）

    private var visibleItems: [MemoryEntry] {
        guard let k = filterKey else { return items }
        return items.filter { Self.groupKey($0) == k }
    }

    private var entrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(filterKey.flatMap { groupName($0) } ?? "全部记忆")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if filterKey != nil {
                    Button("清除筛选") { filterKey = nil }
                        .font(.system(size: Typography.caption))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 2)
            if !loaded {
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Radius.inset)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 64)
                    }
                }
            } else if visibleItems.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(visibleItems) { entryRow($0) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(filterKey == nil ? "还没有记忆条目" : "这个分组还没有条目")
                .font(.system(size: Typography.subhead, weight: .medium))
                .foregroundStyle(.secondary)
            Text("在下方输入框记一句，或聊天时说「记住…」")
                .font(.system(size: Typography.caption))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func entryRow(_ item: MemoryEntry) -> some View {
        Button {
            viewing = item
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: Typography.body))
                    .foregroundStyle(item.isDimmed ? Color.secondary : Color.accentColor)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(item.isDimmed ? Color.secondary : Color.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        MemoStatusChip(item: item)
                        if let d = item.displayDate {
                            Label {
                                Text(d, format: .dateTime.year().month().day())
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.system(size: Typography.caption))
                            .foregroundStyle(.tertiary)
                        }
                        if item.hasSource {
                            Label(item.sourceTitle, systemImage: item.sourceIcon)
                                .font(.system(size: Typography.caption))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
            .background(Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: Radius.inset))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("记忆：\(item.text)")
        .accessibilityHint("查看详情")
    }

    // MARK: 底部快捷输入（走现有写入链路）

    private var canSubmit: Bool {
        !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy
    }

    private var quickInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("记一句话…", text: $newText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: Typography.subhead))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                    .disabled(busy)
                Button {
                    submit()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSubmit ? Color.accentColor : Color.secondary.opacity(0.35))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .accessibilityLabel("记住这句话")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func submit() {
        let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            guard let j = await auth.jsonOrLog("/api/memory/add", method: "POST", body: ["text": t]) else {
                showToast("没记住，再试一次")
                return
            }
            let ok = (j["ok"] as? Bool) ?? false
            guard ok else {
                showToast((j["message"] as? String) ?? "没记住，再试一次")
                return
            }
            // 与设置页同口径：响应带列表字段就地刷新，否则重拉
            if MemoryEntry.hasListField(j) {
                items = MemoryEntry.parse(j)
            } else {
                await refresh()
            }
            newText = ""
            showToast("已记住")
        }
    }

    @ViewBuilder
    private var toastPill: some View {
        if let t = toast {
            Text(t)
                .font(.system(size: Typography.subhead, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.8), in: Capsule())
                .padding(.bottom, 84)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            // 只清自己这一条，不冲掉后来的提示
            if toast == text { toast = nil }
        }
    }

    // MARK: 取数

    private func load() async {
        guard !loaded else { return }
        loaded = true
        await refresh()
    }

    private func refresh() async {
        guard let j = await auth.jsonOrLog("/api/memory/list") else { return }
        let parsed = MemoryEntry.parse(j)
        if parsed.isEmpty && !items.isEmpty && !MemoryEntry.hasListField(j) { return }
        items = parsed
    }
}

// MARK: - 条目详情（只读）
//
// 编辑 / 删除 / 改状态去本页右上角「管理」（设置页 MemoryView），不另造一套编辑 UI。

private struct MemoryEntryDetailSheet: View {
    let entry: MemoryEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(entry.text)
                        .font(.system(size: Typography.body))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                    HStack(spacing: 8) {
                        MemoStatusChip(item: entry)
                        if let d = entry.displayDate {
                            Label {
                                Text(d, format: .dateTime.year().month().day())
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.system(size: Typography.caption))
                            .foregroundStyle(.tertiary)
                        }
                        if entry.hasSource {
                            Label(entry.sourceTitle, systemImage: entry.sourceIcon)
                                .font(.system(size: Typography.caption))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text("编辑、删除或修改状态，请点本页右上角「管理」")
                        .font(.system(size: Typography.caption))
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("记忆详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .accessibilityLabel("记忆详情")
    }
}
