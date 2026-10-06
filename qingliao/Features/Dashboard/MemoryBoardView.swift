import SwiftUI

// MARK: - 记忆一级入口（对标参考设计：健康 Hero 大卡 + 文件夹网格 + 底部快捷输入）
//
// 数据源（与设置页「AI 记忆」同一份）：
//   · 列表 GET /api/memory/list → MemoryEntry.parse
//   · 新增 POST /api/memory/add {"text":}
//   · 编辑 / 删除 / 改状态沿用设置页 MemoryView（管理弹窗）
// 健康小格：HealthStore 结构化数值，取不到显示 "--" 占位，不编假数据。

// MARK: - 看板用的记忆大卡（自包含）

struct MemoryHeroCard: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.colorScheme) private var colorScheme
    @State private var items: [MemoryEntry] = []
    @State private var loaded = false
    @State private var showBoard = false

    var body: some View {
        Button {
            showBoard = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .background(Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("记忆")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Text(countText)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Text(latestText)
                        .font(.system(size: 14))
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
            // 2026-10-07：卡片背景深色适配（之前写死白色）
            .background(colorScheme == .dark ? Color(white: 0.14) : Color.white,
                        in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06),
                    radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBoard) {
            MemoryBoardView()
        }
        .task { await load() }
        .onChange(of: showBoard) { _, presented in
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
        if parsed.isEmpty && !items.isEmpty && !MemoryEntry.hasListField(j) { return }
        items = parsed
        // 2026-10-07：同时拉 Hermes 真实记忆
        await loadHermesMemory()
    }

    // 2026-10-07：Hermes 真实记忆（唯一真源）
    private func loadHermesMemory() async {
        guard let j = try? await auth.json("/api/agent/hermes/inspect/memory", method: "GET"),
              let mem = j["memory"] as? [String: String] else { return }
        hermesMemory = mem["MEMORY.md"]
        hermesUser = mem["USER.md"]
    }
}

// MARK: - 记忆二级页（对标参考设计）

struct MemoryBoardView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var items: [MemoryEntry] = []
    @State private var loaded = false
    @State private var newText = ""
    @State private var busy = false
    @State private var toast: String?
    @State private var showManage = false
    @State private var showHealth = false
    @State private var viewing: MemoryEntry?
    // 2026-10-07：Hermes 真实记忆（唯一真源）
    @State private var hermesMemory: String?
    @State private var hermesUser: String?

    // 健康 mini 统计（取不到则 nil → "--" 占位）
    @State private var healthSteps: Int?
    @State private var healthUpdated: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("全部")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    healthHeroCard
                    // 2026-10-07：Hermes 真实记忆（唯一真源）
                    if hermesMemory != nil || hermesUser != nil {
                        hermesMemoryCard
                    }
                    folderGrid
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .refreshable {
                await refresh()
                await loadHealthMini()
            }
            .safeAreaInset(edge: .bottom) { quickInputBar }
            .navigationTitle("记忆")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showManage = true } label: {
                        Image(systemName: "book.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                    }
                    .accessibilityLabel("管理记忆")
                }
            }
            .sheet(isPresented: $showManage) {
                MemoryView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showHealth) {
                HealthBoardView()
            }
            .sheet(item: $viewing) { entry in
                MemoryEntryDetailSheet(entry: entry)
                    .presentationDetents([.medium])
            }
            .overlay(alignment: .bottom) { toastPill }
            .task {
                await load()
                await loadHealthMini()
            }
        }
        .background(memoryGradient)
    }

    // 2026-10-07：卡片背景色（深色/浅色自适应）
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.14) : Color.white
    }

    private var cardShadowOpacity: Double {
        colorScheme == .dark ? 0.3 : 0.06
    }

    private var memoryGradient: some View {
        // 2026-10-07：深色/浅色自适应（之前写死浅色，深色模式下白字配浅底看不见）
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.12),
                        Color(red: 0.10, green: 0.11, blue: 0.14),
                        Color(red: 0.12, green: 0.12, blue: 0.14)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.94, blue: 0.98),
                        Color(red: 0.96, green: 0.96, blue: 0.97),
                        Color(red: 0.985, green: 0.975, blue: 0.96)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: 健康 Hero 大卡

    // 2026-10-07：Hermes 真实记忆卡（唯一真源）
    private var hermesMemoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.purple, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hermes 记忆")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("AI 的真实记忆 · 唯一真源")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let mem = hermesMemory, !mem.isEmpty {
                Text(mem)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .truncationMode(.tail)
            }
            if let user = hermesUser, !user.isEmpty {
                Divider()
                Text("关于你")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(user)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .truncationMode(.tail)
            }
        }
        .padding(18)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(cardShadowOpacity), radius: 12, x: 0, y: 4)
    }

    private var healthHeroCard: some View {
        Button { showHealth = true } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(red: 1.0, green: 0.42, blue: 0.42), in: Circle())
                    Text("健康")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("\(items.count) 条数据，\(groups.count) 条记录")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("更新于 \(healthUpdated ?? "--")")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    healthMini(icon: "moon.fill", color: .blue, value: "--", unit: "小时 -- 分钟")
                    healthMini(icon: "heart.fill", color: .orange, value: "--", unit: "次/分")
                    healthMini(icon: "heart.fill", color: .yellow, value: "--", unit: "毫秒")
                    healthMini(icon: "figure.walk", color: .green,
                               value: healthSteps.map { "\($0)" } ?? "--", unit: "步")
                }
            }
            .padding(18)
        }
        .buttonStyle(.plain)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 5)
        .accessibilityLabel("健康，打开健康页")
    }

    private func healthMini(icon: String, color: Color, value: String, unit: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(value == "--" ? .secondary : .primary)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: 文件夹网格

    private struct MemoryGroup: Identifiable {
        let key: String
        let name: String
        let isMic: Bool
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
        var result = [MemoryGroup(key: "voice", name: "语音笔记", isMic: true, count: 0)]
        for (key, name) in [("manual", "手动添加"), ("chat", "聊天记录"), ("other", "其他")] {
            let c = counts[key]?.count ?? 0
            if c > 0 {
                result.append(MemoryGroup(key: key, name: name, isMic: false, count: c))
            }
        }
        return result
    }

    private var folderGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(groups) { g in
                Button {
                    if g.key == "voice" {
                        toast = "语音笔记即将上线"
                    } else {
                        showManage = true
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        if g.isMic {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(red: 0.72, green: 0.80, blue: 0.89))
                        }
                        Text(g.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(g.count) 项")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                }
                .buttonStyle(.plain)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
            }
        }
    }

    // MARK: 底部快捷输入

    private var canSubmit: Bool {
        !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy
    }

    private var quickInputBar: some View {
        HStack(spacing: 10) {
            Button { toast = "附件功能即将上线" } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            TextField("记一句话…", text: $newText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 16))
            Button { submit() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(canSubmit ? Color.black : Color.secondary.opacity(0.3), in: Circle())
            }
            .disabled(!canSubmit)
            .accessibilityLabel("记住这句话")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(cardBackground, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var toastPill: some View {
        Group {
            if let t = toast {
                Text(t)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8), in: Capsule())
                    .padding(.bottom, 90)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if toast == t { toast = nil }
                        }
                    }
            }
        }
    }

    // MARK: 数据

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

    private func loadHealthMini() async {
        guard HealthStore.isAvailable else { return }
        if let steps = await HealthStore.shared.todaySteps() {
            healthSteps = Int(steps.rounded())
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        healthUpdated = fmt.string(from: Date())
    }

    private func submit() {
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let (_, resp) = try await auth.request("/api/memory/add", method: "POST",
                                                        body: ["text": text])
                if (200..<300).contains(resp.statusCode) {
                    newText = ""
                    await refresh()
                    toast = "已记住"
                } else {
                    toast = "保存失败"
                }
            } catch {
                toast = "网络不通"
            }
        }
    }
}

// MARK: - 记忆详情弹窗（沿用原实现）

private struct MemoryEntryDetailSheet: View {
    let entry: MemoryEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(entry.text)
                        .font(.system(size: 17))
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
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        }
                        if entry.hasSource {
                            Label(entry.sourceTitle, systemImage: entry.sourceIcon)
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text("编辑、删除或修改状态，请点本页右上角「管理」")
                        .font(.system(size: 12))
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
