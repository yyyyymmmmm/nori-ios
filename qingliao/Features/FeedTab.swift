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
    static let promptKey = "qingliao_feed_prompt"
    static let defaultPrompt = "我的兴趣动态版块，围绕三块内容：科技圈的新动态、AI 圈的进展、好玩的开源项目。"

    var prompt: String {
        didSet { UserDefaults.standard.set(prompt, forKey: Self.promptKey) }
    }
    var units: [FeedUnit] = []
    private var likedIDs: Set<String> = []

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.promptKey)
        self.prompt = (saved?.isEmpty == false) ? saved! : Self.defaultPrompt
    }

    func isLiked(_ id: String) -> Bool { likedIDs.contains(id) }

    func toggleLike(_ id: String) {
        if likedIDs.contains(id) { likedIDs.remove(id) } else { likedIDs.insert(id) }
        Haptics.light()
    }

    /// 约定接口 GET /api/feed/units；后端暂无 → 任何失败都静默留空（诚实空态）
    /// 2026-10-07：把资讯 prompt 传给后端（?prompt=…&limit=6），后端按提示词生成 units；
    /// 无 prompt 时后端走默认，不会坏。
    func load() async {
        let auth = AuthStore()
        var comps = URLComponents(string: auth.serverURL + "/api/feed/units")
        comps?.queryItems = [
            URLQueryItem(name: "prompt", value: prompt),
            URLQueryItem(name: "limit", value: "6"),
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
        guard let list = try? dec.decode([FeedUnit].self, from: data) else { return }
        units = list.sorted { $0.publishedAt > $1.publishedAt }
    }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                        .padding(.top, Spacing.xl)
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
                                    liked: store.isLiked(u.id),
                                    onLike: { store.toggleLike(u.id) },
                                    onDiscuss: { onFillInput("我们来讨论一下这条动态：「\(u.title)」") },
                                    onShowReason: { reasonUnit = u }
                                )
                                Divider()
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
                .padding(.horizontal, Spacing.section)
                .padding(.bottom, 100)   // F线：系统 tab bar 下内容不被遮（原来按悬浮胶囊留的）
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await store.load() }
            .refreshable { await store.load() }
            .sheet(isPresented: $showPrompt) { promptSheet }
            .sheet(item: $reasonUnit) { u in
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
                    .a11yGlass(.regular, in: Circle(), stroke: Color.primary.opacity(0.08))
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
                    .a11yGlass(.regular, in: Circle(), stroke: Color.primary.opacity(0.08))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑动态版块提示词")
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
            Text("动态版块由上面的提示词驱动")
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundStyle(.secondary)
            Text("feed 内容服务暂未连接")
                .font(.system(size: Typography.subhead))
                .foregroundStyle(.tertiary)
            // v4.x item5：空态加指引。暂无到「连接设置」的现成导航路径，不发明导航，只给文案。
            Text("连接 Hermes 后，这里会按你的提示词生成动态")
                .font(.system(size: Typography.subhead))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: prompt 编辑 sheet（对标 Muse 深色卡片）

    private var promptSheet: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("动态版块说明")
                    .font(.system(size: Typography.titleXL, weight: .bold))
                    .foregroundStyle(.white)
                Text("你的动态版块由以下指示驱动。你对此提示做出的任何编辑都将应用于今后的动态版块帖子。")
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
                        store.prompt = draftPrompt
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
    let liked: Bool
    let onLike: () -> Void
    let onDiscuss: () -> Void
    let onShowReason: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: categoryIcon(unit.category))
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .top)

            VStack(alignment: .leading, spacing: 8) {
                Text(unit.title)
                    .font(.system(size: Typography.title, weight: .semibold))
                    .foregroundStyle(.primary)

                linkedBody(unit.bodyMarkdown)
                    .font(.system(size: Typography.body))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)

                if let img = unit.imageURL, let url = URL(string: img) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.secondary.opacity(0.1)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.6, contentMode: .fill)
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
        }
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
