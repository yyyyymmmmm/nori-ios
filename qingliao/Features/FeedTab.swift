import SwiftUI

// MARK: - 灰度重做 2026-10-06 晚（C 路）：资讯 tab = Muse「动态」feed
//
// 对标 Muse 动态页：顶栏（menu / Nori头像胶囊 / sliders）+ 大标题「动态」
// + prompt 胶囊框 + 无边框 feed 卡片（分割线分隔）。
// 数据：FeedStore；prompt 存 UserDefaults；units 尝试 GET /api/feed/units，
// 后端暂无此接口 → 失败优雅降级，显示诚实空态（不编造假内容）。

/// 动态流里的一条内容
struct FeedUnit: Identifiable, Codable, Sendable {
    var id: String
    var title: String
    var bodyMarkdown: String
    /// tech（科技圈）/ ai（AI 圈）/ oss（开源项目）
    var category: String
    var imageURL: String?
    var publishedAt: Date
    var likes: Int
}

@Observable @MainActor
final class FeedStore {
    // v4.4.x：prompt 存后端（/api/agent/feed/prompt），换设备一致
    static let defaultPrompt = "科技、AI、效率工具"
    private static let promptCacheKey = "nori_feed_prompt_v1"
    private static let promptDirtyKey = "nori_feed_prompt_pending_sync_v1"
    private static let promptUserSavedKey = "nori_feed_prompt_user_saved_v1"

    var prompt: String
    var units: [FeedUnit] = []
    // 2026-10-07：分页
    var hasMore = true
    private var loadingMore = false
    private var likedIDs: Set<String> = []
    private let auth = AuthStore()

    init() {
        // 先用本机上次明确保存的值，避免登录/首屏网络请求失败时短暂退回另一个默认提示词。
        prompt = UserDefaults.standard.string(forKey: Self.promptCacheKey) ?? Self.defaultPrompt
    }

    func loadPrompt() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.promptUserSavedKey),
           let cached = defaults.string(forKey: Self.promptCacheKey), !cached.isEmpty {
            // 用户明确保存过后以本机值为主；服务器值丢失/回滚时自动补写，不重置用户偏好。
            prompt = cached
            if defaults.bool(forKey: Self.promptDirtyKey) {
                await syncPrompt(cached)
            } else if let remote = try? await auth.json("/api/agent/feed/prompt", method: "GET"),
                      (remote["prompt"] as? String) != cached {
                defaults.set(true, forKey: Self.promptDirtyKey)
                await syncPrompt(cached)
            }
            return
        }
        guard let j = try? await auth.json("/api/agent/feed/prompt", method: "GET"),
              let remote = j["prompt"] as? String else { return }
        let value = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        prompt = value
        UserDefaults.standard.set(value, forKey: Self.promptCacheKey)
    }

    func savePrompt(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        // 先落本机，后同步后端：即使 NAS 暂时不可达，重新登录也保持用户刚保存的主题。
        prompt = cleaned
        UserDefaults.standard.set(cleaned, forKey: Self.promptCacheKey)
        UserDefaults.standard.set(true, forKey: Self.promptDirtyKey)
        UserDefaults.standard.set(true, forKey: Self.promptUserSavedKey)
        Task { await syncPrompt(cleaned) }
    }

    private func syncPrompt(_ value: String) async {
        guard let result = try? await auth.json("/api/agent/feed/prompt", method: "POST",
                                                body: ["prompt": value]),
              result["ok"] as? Bool == true else { return }
        UserDefaults.standard.set(value, forKey: Self.promptCacheKey)
        UserDefaults.standard.set(false, forKey: Self.promptDirtyKey)
    }

    func isLiked(_ id: String) -> Bool { likedIDs.contains(id) }

    func toggleLike(_ id: String) {
        if likedIDs.contains(id) { likedIDs.remove(id) } else { likedIDs.insert(id) }
        Haptics.light()
    }

    /// 约定接口 GET /api/feed/units；后端暂无 → 任何失败都静默留空（诚实空态）
    /// 2026-10-07：把资讯 prompt 传给后端（?prompt=…&limit=6），后端按提示词生成 units；
    /// 无 prompt 时后端走默认，不会坏。
    /// 2026-10-07：分页（paged=1 返回 {units, has_more}）
    func load() async {
        let auth = AuthStore()
        var comps = URLComponents(string: auth.serverURL + "/api/feed/units")
        comps?.queryItems = [
            URLQueryItem(name: "prompt", value: prompt),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "paged", value: "1"),
        ]
        guard let url = comps?.url else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        if !auth.token.isEmpty {
            req.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        // 新格式 {units, has_more}
        if let paged = try? dec.decode(PagedFeed.self, from: data) {
            units = paged.units.sorted { $0.publishedAt > $1.publishedAt }
            hasMore = paged.has_more
            return
        }
        // 兼容老格式 [FeedUnit]
        guard let list = try? dec.decode([FeedUnit].self, from: data) else { return }
        units = list.sorted { $0.publishedAt > $1.publishedAt }
        hasMore = false
    }

    /// 加载更多（分页）
    func loadMore() async {
        guard hasMore, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        let auth = AuthStore()
        var comps = URLComponents(string: auth.serverURL + "/api/feed/units")
        comps?.queryItems = [
            URLQueryItem(name: "prompt", value: prompt),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "offset", value: "\(units.count)"),
            URLQueryItem(name: "paged", value: "1"),
        ]
        guard let url = comps?.url else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        if !auth.token.isEmpty {
            req.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let paged = try? dec.decode(PagedFeed.self, from: data) else { return }
        let newUnits = paged.units.sorted { $0.publishedAt > $1.publishedAt }
        // 去重追加
        let existingIDs = Set(units.map { $0.id })
        units.append(contentsOf: newUnits.filter { !existingIDs.contains($0.id) })
        hasMore = paged.has_more
    }
}

// 2026-10-07：分页响应
private struct PagedFeed: Decodable {
    let units: [FeedUnit]
    let has_more: Bool
}

struct FeedTabView: View {
    let onAskAI: (String) -> Void
    let onFillInput: (String) -> Void
    @State private var store = FeedStore()
    @State private var showPrompt = false
    @State private var draftPrompt = ""
    @State private var reasonUnit: FeedUnit?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let contentWidth = max(0, geometry.size.width - Spacing.section * 2)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("动态")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(.top, Spacing.lg)
                        promptBox
                            .padding(.top, Spacing.xl)
                        if store.units.isEmpty {
                            feedEmptyState
                        } else {
                            VStack(spacing: 0) {
                                ForEach(store.units) { u in
                                    FeedUnitCard(
                                        unit: u,
                                        availableWidth: contentWidth,
                                        liked: store.isLiked(u.id),
                                        onLike: { store.toggleLike(u.id) },
                                        onDiscuss: { onFillInput("我们来讨论一下这条动态：「\(u.title)」") },
                                        onShowReason: { reasonUnit = u }
                                    )
                                    Divider()
                                }
                                if store.hasMore {
                                    Button {
                                        Task { await store.loadMore() }
                                    } label: {
                                        Text("加载更多")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, Spacing.xs)
                        }
                    }
                    .padding(.horizontal, Spacing.section)
                    .frame(width: geometry.size.width, alignment: .leading)
                    .padding(.bottom, 100)
                }
                .scrollEdgeEffectHidden(true)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            // 顶栏固定在页面视口，信息流从它下面滚过；采用系统滚动边缘材质。
            .safeAreaBar(edge: .top) {
                topBar
                    .padding(.horizontal, Spacing.section)
                    .padding(.top, Spacing.xl)
                    .background(Color(uiColor: .systemBackground))
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await store.loadPrompt()
                await store.load()
            }
            .refreshable { await store.load() }
            .sheet(isPresented: $showPrompt) { promptSheet }
            .sheet(item: $reasonUnit) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    Text("为什么推荐这条")
                        .font(.system(size: 20, weight: .semibold))
                    Text("根据你的兴趣设置「\(store.prompt)」为你推荐。")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(24)
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: 顶栏：menu / Nori头像胶囊 / sliders（对标 Muse 动态页）

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                NotificationCenter.default.post(name: .qingliaoToggleSidebar, object: nil)
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: Typography.headline))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .opaqueChrome(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开侧边栏")

            Spacer()

            // F线：Muse 式 AI 形象胶囊（五页统一），点进任务中心
            AITopCapsule()

            Spacer()

            Button { Haptics.tap(); showPrompt = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: Typography.headline))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .opaqueChrome(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑动态关注主题")
        }
    }

    // MARK: prompt 胶囊框（点 → 编辑 sheet）

    private var promptBox: some View {
        Button { showPrompt = true } label: {
            Text(store.prompt)
                .font(.system(size: Typography.body))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, Spacing.section)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: 诚实空态（不编造假内容）

    private var feedEmptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "newspaper")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("动态来自已配置的真实资讯源")
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundStyle(.secondary)
            Text("当前没有可展示的 RSS 条目")
                .font(.system(size: Typography.subhead))
                .foregroundStyle(.tertiary)
            // v4.x item5：空态加指引。暂无到「连接设置」的现成导航路径，不发明导航，只给文案。
            Text("在资讯设置中添加可访问的 RSS 源后，动态会自动更新；Hermes 只负责按关注主题排序，不会编造内容。")
                .font(.system(size: Typography.subhead))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: prompt 编辑 sheet（对标 Muse 深色卡片）

    private var promptSheet: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("动态关注主题")
                    .font(.system(size: Typography.titleXL, weight: .bold))
                    .foregroundStyle(.white)
                Text("动态只展示资讯设置中 RSS 源的真实文章。Hermes 会按这里的关注主题调整排序；上游不可用时仍展示 RSS 原始顺序。")
                    .font(.system(size: Typography.body))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(3)
                Divider()
                    .background(.white.opacity(0.12))
                TextEditor(text: $draftPrompt)
                    .font(.system(size: Typography.title))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xl)
                    .frame(minHeight: 200)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                HStack(spacing: 12) {
                    Button { showPrompt = false } label: {
                        Text("取消")
                            .font(.system(size: Typography.title, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        store.savePrompt(draftPrompt)
                        showPrompt = false
                    } label: {
                        Text("保存")
                            .font(.system(size: Typography.title, weight: .medium))
                            .foregroundStyle(draftPrompt == store.prompt ? .white.opacity(0.4) : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                Color.white.opacity(draftPrompt == store.prompt ? 0.08 : 0.22),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(draftPrompt == store.prompt)
                }
                .padding(.top, Spacing.xs)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.11))
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        // v4.4：对齐 SheetConventions——圆角用系统默认（删 28 自定义），指示器一律 visible
        .presentationDragIndicator(.visible)
        .onAppear { draftPrompt = store.prompt }
    }
}

// MARK: - 动态卡片（无边框，分割线分隔；链接蓝色可点）

private struct FeedUnitCard: View {
    let unit: FeedUnit
    let availableWidth: CGFloat
    let liked: Bool
    let onLike: () -> Void
    let onDiscuss: () -> Void
    let onShowReason: () -> Void

    // 两侧各留 12pt 的正文安全边距，图文都在内容列内换行/裁切，不顶到屏幕边缘。
    private var textColumnWidth: CGFloat { max(0, availableWidth - 64) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: categoryIcon(unit.category))
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .top)

            VStack(alignment: .leading, spacing: 8) {
                Text(unit.title)
                    .font(.system(size: Typography.title, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: textColumnWidth, alignment: .leading)

                linkedBody(unit.bodyMarkdown)
                    .font(.system(size: Typography.body))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: textColumnWidth, alignment: .leading)

                if let img = unit.imageURL, let url = URL(string: img) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.secondary.opacity(0.1)
                    }
                    .frame(width: textColumnWidth, height: max(120, textColumnWidth / 1.6))
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }

                HStack(spacing: 18) {
                    Button(action: onLike) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: Typography.headline))
                            .foregroundStyle(liked ? .red : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(liked ? "取消点赞" : "点赞")

                    Button(action: onDiscuss) {
                        Text("讨论")
                            .font(.system(size: Typography.body))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Text(RelativeTime.string(since: unit.publishedAt.timeIntervalSince1970))
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.secondary)
                    Button(action: onShowReason) {
                        Image(systemName: "info.circle")
                            .font(.system(size: Typography.title))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Spacing.xs)
            }
            .frame(width: textColumnWidth, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(width: availableWidth, alignment: .leading)
        .padding(.vertical, Spacing.section)
    }

    private func categoryIcon(_ c: String) -> String {
        switch c {
        case "tech": return "cpu"
        case "ai": return "sparkles"
        case "oss": return "chevron.left.slash.chevron.right"
        default: return "newspaper"
        }
    }

    /// body 里的 [文字](url) 渲染成蓝色可点
    private func linkedBody(_ markdown: String) -> Text {
        if let attr = try? AttributedString(markdown: markdown) {
            return Text(attr)
        }
        return Text(markdown)
    }

}
