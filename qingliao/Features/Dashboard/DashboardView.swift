import SwiftUI

// MARK: - 看板页（w5 重做：对标 Muse 设计语言）
//
// 结构：Hero 大卡（家庭状态总览）→ 快捷入口（今日建议通栏 + 2 列文件夹网格）
//       → 服务状态 → 动态信息流（任务执行记录 / 自动规则 / 连接器动态 / 用量一行）。
// 分组标题统一小灰字（groupTitle），圆角：Hero 28pt，其余沿用卡片体系 16pt。
//
// 收敛（w5）：diagnoseBlock 并入 Hero 一句话（删独立卡）；pinBlock 从看板移除
// （聊天长按已有钉一钉入口）；routerBlock 状态并入服务状态区的路由器行（删独立栏目）；
// usageBlock + tokenUsageBlock 合并为信息流里"用量"一行。
// 旧的 12 栏目自定义排序/隐藏体系（BoardCard / BoardCardOrder / 拖动栏目头）
// 随固定结构一并移除 —— BoardCardOrder.swift 等文件保留（别的入口不用动它，也不报错）。

// v3.9.25：新增 weather（天气弹窗）——注意 switch 穷尽性由 ql.py ios check 把关
// v3.9.46：新增 lock/temps/doorbell/cpu/memory 五张详情弹窗（用户点名"卡片点击要看细节"）
//         + alarmArmAsk（布防/撤防确认）走 confirmationDialog，不占 sheet 通道
// v3.9.54：CPU / 内存两张详情弹窗**删除**（用户：「去掉CPU和内存卡片的弹窗，
//         只显示卡片，点击不再弹窗」）——enum 少两个 case，下面的 `.sheet(item:)` switch 同步少两个分支。
//         ⚠️ 新增/删除 case 时两处一起改，穷尽性才会被 CI 那道检查抓住。
// w5：新增 sceneSheet / deviceSheet / automationSheet / routerSheet / todoSheet
//     五个文件夹式入口弹窗（同样两处一起改）。
enum DashboardSheet: String, Identifiable {
    case lights, climate, service, serviceHermes, disks, docker, weather, connectorPanel
    case lock, temps, doorbell
    case sceneSheet, deviceSheet, automationSheet, routerSheet, todoSheet
    var id: String { rawValue }
}

/// v2.0.104：剩余时间文案（倒计时显示）
/// v4.4.x item5③：从 DashboardView 方法提升为文件级函数，供 AutomationCountdownCard 用
private func remainText(_ s: Int) -> String {
    if s >= 3600 { return String(format: "%d小时%02d分", s / 3600, (s % 3600) / 60) }
    if s >= 60 { return String(format: "%d分%02d秒", s / 60, s % 60) }
    return "\(s) 秒后执行"
}

/// v4.4.x item5③：自动化倒计时卡——1s TimelineView 下沉到卡片内部。
/// 由头：原先 TimelineView 直接包在 automationsBlock 的 ForEach 行里，时间源挂在栏目级
/// 视图树上；下沉后每秒 tick 只重绘这一张卡，整页其余部分不受影响。
private struct AutomationCountdownCard: View {
    let item: AutomationItem

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            // v2.0.104b：runAt 在未来，timeIntervalSince(a.runAt) 是负值——
            // 修正为 runAt.timeIntervalSince(now) 得剩余正秒数（原实现倒计时反向递增）
            let remain = max(Int(item.runAt.timeIntervalSince(ctx.date)), 0)
            DeviceCard(name: item.name,
                       icon: "timer",
                       value: remainText(remain),
                       sub: "到点自动执行 · 长按取消",
                       status: .on)
                .opacity(remain <= 0 ? 0.35 : 1)
        }
    }
}

/// w5：信息流任务行文案。remainText 的"秒"分支自带"后执行"后缀，分钟以上才需补后缀。
private func feedRemainText(_ a: AutomationItem) -> String {
    let r = max(Int(a.runAt.timeIntervalSince(Date())), 0)
    return r < 60 ? remainText(r) : "剩余" + remainText(r) + "后执行"
}

struct DashboardView: View {
    // v3.4.26：看板是否激活（DockTabView 直传 selected == .dashboard）——替代 Leave/Refresh 通知
    // 激活才跑 30s 轮询/切回立即刷新；去通知隐式耦合，生命周期收进自身
    var isActive: Bool = true
    @Environment(AuthStore.self) private var auth
    @Environment(\.colorScheme) private var scheme   // v3.0.9：背景毛玻璃化深浅适配
    // v3.4.28：横屏限宽
    @Environment(\.horizontalSizeClass) private var hSizeBoard

    @State private var nas = NASStatus()
    // v3.0.36：模型使用量栏（/api/nas/providers-usage）——w5 只取个数进"用量"一行，不再逐卡展示
    @State private var providerUsages: [ProviderUsage] = []
    @State private var usageError = ""
    // v3.9.82：token 用量卡（今日/本月，单位 M；后端读 Hermes state.db 的真实用量）
    @State private var tokenUsage: TokenUsage?
    @State private var tokenUsageError = ""
    // w5：用量行"用量"长按重置的确认态（原 TokenUsageCard 的长按重置能力保留）
    @State private var showUsageResetConfirm = false

    @State private var haEntities: [HAEntity] = []
    @State private var router = RouterStatus()
    /// v3.9.41（SR36）：Clash 起停的在途闸门。原先放在 `RouterStatus.busy` 里，
    /// 而 loadRouter() 每轮整体替换 `router`（parse 出来的 busy 恒 false）→ 闸门被并发刷新解掉。
    @State private var clashBusy = false
    /// v3.9.41（SR39）：refresh() 的在途闸门（见该方法内注释）
    @State private var refreshing = false
    /// v4.4.x item5①：上次聚合加载的时间戳（SessionsView v3.0.7 三秒节流的同款思路）。
    /// 切回看板时距上次不足 dashboardFreshness 则整批跳过——零网络、@State 不碰 = 零重绘。
    @State private var lastLoadAt: Date?
    /// v4.4.x item5①：看板全量新鲜度窗口（秒）——对齐 30s 轮询间隔，轮询本来就会兜底
    private static let dashboardFreshness: TimeInterval = 30
    @State private var scrollPos = ScrollPosition()

    @State private var activeSheet: DashboardSheet?
    // v3.9.25：天气弹窗是否真的开过 —— 关灯/空调/磁盘/docker 弹窗时不该顺带重取天气
    @State private var weatherSheetShown = false
    @Namespace private var sheetZoomNS   // v3.9.0：看板卡片 → 详情弹窗 的 zoom 转场
    // v2.0.72：Docker 容器数量（看板卡片状态）
    @State private var dockerContainerCount = 0
    @State private var sceneRunning = false   // v2.0.102：场景执行防抖
    // v2.0.96：场景（AI 生成动作组，一键执行）
    @State private var scenes: [SceneItem] = []
    // v2.0.104：定时自动化（AI 生成"X分钟后执行Y"，到点自动执行后消失）
    @State private var automations: [AutomationItem] = []
    /// v3.9.41（SR38）：取消自动化的失败回执（原先 DELETE 返回值整个丢弃）
    @State private var automationError = ""
    // v3.9.21：自动规则（条件触发；规则本体在后端 rules_engine 求值）
    @State private var rules: [RuleItem] = []
    @State private var pendingRuleDelete: RuleItem?
    // v2.0.113：场景执行确认（含危险动作时弹窗防误触）
    @State private var confirmSceneRun: SceneItem?
    @State private var sceneResult = ""
    @State private var showSceneResult = false
    // v2.0.116：智能建议（天气/NAS/设备 → Agent 生成）
    @State private var smartSuggestion = ""
    @State private var smartLoading = false
    // v3.0.18：设备一键体检 —— w5 并入 Hero 一句话，只保留 level/summary（删独立卡）
    @State private var diagnoseLevel = ""
    @State private var diagnoseSummary = ""
    // w5：任务中心 / 待办的数据（Hero 四宫格用；@Observable 单例，@State 持有即响应式）
    @State private var taskStore = TaskCenterStore.shared
    @State private var todoStore = TodoStore.shared
    // v3.9.46：安防卡点击布防/撤防。confirmArmTarget 走 confirmationDialog（危险动作既有方言，
    // 同「执行场景」「停止服务」）；alarmBusy 是下发在途闸门；alarmError 是失败回执。
    @State private var confirmArmTarget: Bool?
    @State private var alarmBusy = false
    @State private var alarmError = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                // v2.0.133f：VStack → LazyVStack——TabView 切页动画期间看板全量卡片一次性布局是切页卡顿主因，
                // 懒加载后只渲染可见卡片（与 v2.0.132 ChatView 消息列表同款方案；看板无批量移除路径，安全）
                LazyVStack(alignment: .leading, spacing: Spacing.section) {
                    // F线：大标题（原来 PageHeader 的标题位，五页统一 Muse 式）
                    Text("看板")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, Spacing.lg)

                    // 2026-10 简化：只留三块——Nori 今日建议置顶 + 健康 Hero + 记忆 Hero
                    // 其他（快捷入口/服务状态/动态信息流）全砍
                    TodaySuggestionCard()

                    HealthHeroCard()

                    MemoryHeroCard()
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, 100)
                // v3.4.28：横屏限宽居中
                .frame(maxWidth: .infinity)
                .frame(maxWidth: AdaptiveLayout.contentMaxWidth(hSizeBoard))
            }
            .scrollEdgeEffectHidden(true)
            // v4.0.62：滚边玻璃（`safeAreaBar`）——页头挂在滚动视图上，
            // 滚动时内容在页头下沿走系统级模糊/渐隐（同生活页 v4.0.61 试点形态，逐字同款）。
            // 回退：删掉本块、在 VStack 第一行恢复 PageHeader(...) 即可。
            .safeAreaBar(edge: .top) {
                // F线 2026-10-06：Muse 式顶栏 —— 左侧边栏 / 中 AI 形象胶囊 / 右天气（入口不变）。
                HStack {
                    Button {
                        Haptics.tap()
                        NotificationCenter.default.post(name: .qingliaoToggleSidebar, object: nil)
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: Typography.headline))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .a11yGlass(.clear, in: Circle(), stroke: Color.primary.opacity(0.08))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开侧边栏")

                    Spacer()

                    AITopCapsule()

                    Spacer()

                    // v2.0.87u：右上角天气（小图标 + 温度）
                    // v3.9.25：本地模式此前点徽章**完全没反应**（纯展示），本次补入口 → 天气弹窗
                    Button {
                        activeSheet = .weather
                    } label: {
                        WeatherBadge(temp: weatherTemp, code: weatherCode, city: weatherCity)
                    }
                    .buttonStyle(PressStyle(scale: 0.94))
                    .matchedTransitionSource(id: DashboardSheet.weather.id, in: sheetZoomNS)   // v3.9.25：徽章 → 天气弹窗 zoom
                    .accessibilityLabel("查看天气")
                }
                .padding(.horizontal, Spacing.xxl)
                .background(.clear)
            }
            .modifier(DashboardScrollChrome(host: self))
            .modifier(DashboardDialogChrome(host: self))
        }
        // v2.0.96b：切回看板立即刷新（对话里生成场景后看板即时联动）
        // v2.0.102：单一刷新入口（.task 首刷+轮询）——修并发双刷/旧响应覆盖
        // v3.4.26：通知 → isActive 参数直传生命周期驱动
        .task(id: isActive) {
            await dashboardTask()
        }
    }

    // MARK: - w5 分组标题（小灰字，无拖动）

    /// w5：分组标题 = 小灰字（Muse 式弱分组），替代旧的栏目头（标题 + 拖动把手 + 长按排序）。
    private func groupTitle(_ s: String) -> some View {
        Text(s)
            .font(.system(size: Typography.subhead, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - w5-1 总览 Hero

    /// Nori 后端存活（"Nori后端"服务卡同源）
    private var noriAlive: Bool { nas.qingliaoAlive }

    /// 未到期的自动化 = 进行中任务
    private var activeAutomationCount: Int {
        automations.filter { $0.runAt > Date() }.count
    }

    /// 未完成待办
    private var openTodoCount: Int {
        todoStore.todos.filter { !$0.done }.count
    }

    /// Hero 一句话：设备在线 + 进行中任务 + 体检（原 diagnoseBlock 并入此处，删独立卡）
    private var heroSummary: String {
        var parts = ["\(haAvailableCount) 台设备在线", "\(activeAutomationCount) 个任务执行中"]
        switch diagnoseLevel {
        case "ok": parts.append("体检良好")
        case "warn": parts.append("体检有待留意项")
        case "error": parts.append("体检发现异常")
        default: break
        }
        return parts.joined(separator: " · ")
    }

    /// w5-1：顶部 Hero「家庭状态总览」——左 Nori 状态 + 一句话；右 2x2 mini tiles（数字，点击进现有页/sheet）。
    @ViewBuilder
    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(noriAlive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text("Nori · \(noriAlive ? "运行中" : "已停止")")
                    .font(.system(size: Typography.body, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: Typography.caption, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .tapButton { activeSheet = .service }
            .accessibilityLabel("Nori 状态：\(noriAlive ? "运行中" : "已停止")，点击查看服务详情")

            Text(heroSummary)
                .font(.system(size: Typography.subhead))
                .foregroundStyle(.secondary)
                .accessibilityLabel("家庭状态总览：\(heroSummary)")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.md),
                                GridItem(.flexible(), spacing: Spacing.md)],
                      spacing: Spacing.md) {
                heroTile(icon: "timer", tint: .orange, title: "进行中任务",
                         count: activeAutomationCount,
                         a11y: "进行中任务 \(activeAutomationCount) 个，点击查看自动化") {
                    activeSheet = .automationSheet
                }
                heroTile(icon: "checklist", tint: .blue, title: "今日待办",
                         count: openTodoCount,
                         a11y: "今日待办 \(openTodoCount) 个未完成，点击速记待办") {
                    activeSheet = .todoSheet
                }
                heroTile(icon: "wifi", tint: .green, title: "在线设备",
                         count: haAvailableCount,
                         a11y: "在线设备 \(haAvailableCount) 台，点击查看智能家居") {
                    activeSheet = .deviceSheet
                }
                heroTile(icon: "bell", tint: .red, title: "待处理提醒",
                         count: taskStore.uncompleted,
                         a11y: "待处理提醒 \(taskStore.uncompleted) 个，点击打开任务中心") {
                    // 既有链路：侧边栏 / AI 胶囊同款通知 → ChatView 弹任务中心，不新造状态
                    NotificationCenter.default.post(name: .qingliaoOpenTaskCenter, object: nil)
                }
            }
        }
        .padding(Spacing.xxl)
        .dashboardCard(cornerRadius: 28)   // w5：Hero 大圆角 ~28pt
    }

    /// Hero 右区 mini tile：图标 + 大数字 + 小标题
    private func heroTile(icon: String, tint: Color, title: String, count: Int,
                         a11y: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: Typography.title))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: Typography.titleXL, weight: .bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text(title)
                        .font(.system(size: Typography.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }

    // MARK: - w5-2 快捷入口

    /// 今日建议横向通栏卡（内容复用原 smartSuggestionBlock）
    @ViewBuilder
    private var suggestionBanner: some View {
        // v2.0.116：智能建议（基于天气/NAS/设备状态，Agent 生成）
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                    .foregroundStyle(.purple)
                Text("今日建议")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !smartSuggestion.isEmpty {
                    Button {
                        Task { await loadSmartSuggestion() }
                    } label: {
                        // v3.9.4：只留文字 + 胶囊（去图标）
                        Text("重新生成")
                            .font(.system(size: Typography.tiny))
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.xs)
                            .glassPillStroke()
                    }
                    .buttonStyle(PressStyle())   // v3.4.29：统一按压反馈
                    .foregroundStyle(Color.accentColor)
                }
            }
            if smartLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("正在分析家庭状态…")
                        .font(.system(size: Typography.subhead))
                        .foregroundStyle(.secondary)
                }
            } else if !smartSuggestion.isEmpty {
                Text(smartSuggestion)
                    .font(.system(size: Typography.subhead))
                    .lineSpacing(LineSpacing.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    Task { await loadSmartSuggestion() }
                } label: {
                    Text("生成智能建议")
                        .font(.system(size: Typography.subhead, weight: .medium))
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.vertical, Spacing.sm)
                        .glassPillStroke()
                }
                .buttonStyle(PressStyle())   // v3.4.29：统一按压反馈
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
        .accessibilityLabel("今日建议。\(smartSuggestion.isEmpty ? "暂无建议，可生成" : smartSuggestion)")
    }

    /// w5-2：2 列文件夹网格（场景 / 设备 / 自动化 / 连接器）——文件夹式白卡 + 计数，点击进对应弹窗/页
    private var folderGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            folderCard(icon: "bolt.fill", tint: .yellow, title: "场景",
                       countText: "\(scenes.count) 个",
                       a11y: "场景，\(scenes.count) 个，点击管理") {
                activeSheet = .sceneSheet
            }
            .matchedTransitionSource(id: DashboardSheet.sceneSheet.id, in: sheetZoomNS)
            folderCard(icon: "house.fill", tint: .blue, title: "设备",
                       countText: "\(haAvailableCount) 台在线",
                       a11y: "设备，\(haAvailableCount) 台在线，点击控制") {
                activeSheet = .deviceSheet
            }
            .matchedTransitionSource(id: DashboardSheet.deviceSheet.id, in: sheetZoomNS)
            folderCard(icon: "timer", tint: .orange, title: "自动化",
                       countText: "\(automations.count) 个",
                       a11y: "自动化，\(automations.count) 个，点击管理") {
                activeSheet = .automationSheet
            }
            .matchedTransitionSource(id: DashboardSheet.automationSheet.id, in: sheetZoomNS)
            folderCard(icon: "rectangle.connected.to.line.2", tint: .teal, title: "连接器",
                       countText: "工具 · 家居 · 生活",
                       a11y: "连接器，点击查看工具服务总览") {
                activeSheet = .connectorPanel
            }
            .matchedTransitionSource(id: DashboardSheet.connectorPanel.id, in: sheetZoomNS)
        }
    }

    /// 文件夹式白卡：图标底板 + 标题 + 计数 + 右箭头
    private func folderCard(icon: String, tint: Color, title: String, countText: String,
                           a11y: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: Typography.title, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.inset))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: Typography.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(countText)
                        .font(.system(size: Typography.caption))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: Typography.caption, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.xl)
            .dashboardCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }

    // MARK: - w5 内容区块（无标题纯内容；标题由分组或弹窗提供）

    /// 智能家居设备栅格（内容复用原 homeDevicesBlock；弹窗里展示）
    @ViewBuilder
    private var homeDevicesContent: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            DeviceCard(name: "开关", icon: "lightbulb.fill", value: haLights, sub: "\(lightsOn) 盏开启 · 点击控制", status: lightsOn > 0 ? .on : .off)
                .tapButton { activeSheet = .lights }
                .matchedTransitionSource(id: DashboardSheet.lights.id, in: sheetZoomNS)   // v3.9.0：卡片→详情 zoom
            DeviceCard(name: "空调", icon: "air.conditioner.horizontal", value: haClimate, sub: "\(climateOn) 台运行中 · 点击控制", status: climateOn > 0 ? .on : .off)
                .tapButton { activeSheet = .climate }
                .matchedTransitionSource(id: DashboardSheet.climate.id, in: sheetZoomNS)   // v3.9.0：卡片→详情 zoom
            // v3.9.46：门锁/猫眼/温度三张只读卡接上详情弹窗；安防卡接上布防/撤防
            // （sub 文案同时当"可点"的提示，样式与既有 灯/空调 卡一致：tapButton + zoom 转场）
            DeviceCard(name: "门锁", icon: "lock.fill", value: haLockBattery,
                       sub: "点击看锁体状态", status: .on)
                .tapButton { activeSheet = .lock }
                .matchedTransitionSource(id: DashboardSheet.lock.id, in: sheetZoomNS)
            DeviceCard(name: "猫眼", icon: "video.fill", value: haDoorbellBattery,
                       sub: (haDoorbellOnline ? "在线" : "离线") + " · 点击详情",
                       status: haDoorbellOnline ? .on : .off)
                .tapButton { activeSheet = .doorbell }
                .matchedTransitionSource(id: DashboardSheet.doorbell.id, in: sheetZoomNS)
            DeviceCard(name: "安防", icon: "shield.fill", value: haAlarm,
                       sub: alarmSub, status: haAlarmArmed ? .on : .warn)
                .tapButton { requestArm(!haAlarmArmed) }
            DeviceCard(name: "温度", icon: "thermometer", value: haTemp,
                       sub: "室内温度 · 点击看各房间", status: .on)
                .tapButton { activeSheet = .temps }
                .matchedTransitionSource(id: DashboardSheet.temps.id, in: sheetZoomNS)
        }
    }

    /// 智慧场景（内容复用原 scenesBlock；弹窗里展示）
    @ViewBuilder
    private var scenesContent: some View {
        // v2.0.96：场景（AI 对话生成动作组，点一下逐条执行）
        // v2.0.96c：空态可点击刷新（TabView 切 tab 不触发 onAppear 的 iOS 版本差异兜底）
        if scenes.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: Typography.caption))
                    .foregroundStyle(.tertiary)
                Text("暂无场景")
                    .font(.system(size: Typography.subhead))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    // v3.9.4：刷新统一为「文字 + 胶囊」（去图标）
                    Text("刷新")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.xs)
                        .glassPillStroke()
                }
                .buttonStyle(PressStyle())
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .dashboardCard()   // v3.8.1：空态提示条统一 16
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(scenes) { s in
                    DeviceCard(name: s.name,
                               icon: "bolt.fill",
                               value: "\(s.actionCount) 个动作",
                               sub: "点击执行 · 长按删除",
                               status: .on)
                        .tapButton { runScene(s) }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteScene(s)
                            } label: {
                                Label("删除场景", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    /// 自动化（内容复用原 automationsBlock；弹窗里展示完整管理）
    @ViewBuilder
    private var automationsContent: some View {
        // v2.0.104：自动化（AI 生成"X分钟后执行Y"，倒计时到点自动执行后消失）
        if automations.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: Typography.caption))
                    .foregroundStyle(.tertiary)
                Text("暂无自动化")
                    .font(.system(size: Typography.subhead))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    // v3.9.4：刷新统一为「文字 + 胶囊」（去图标）
                    Text("刷新")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.xs)
                        .glassPillStroke()
                }
                .buttonStyle(PressStyle())
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .dashboardCard()   // v3.8.1：空态提示条统一 16
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(automations) { a in
                    // v4.4.x item5③：1s 倒计时的 TimelineView 下沉到卡片内部
                    // （AutomationCountdownCard）——每秒 tick 只重绘这一张卡，不驱动栏目/整页
                    AutomationCountdownCard(item: a)
                        .contextMenu {
                            Button(role: .destructive) {
                                cancelAutomation(a)
                            } label: {
                                Label("取消自动化", systemImage: "xmark.circle")
                            }
                        }
                }
            }
        }
        // v3.9.41（SR38）：取消失败的可见回执
        if !automationError.isEmpty {
            Text("⚠️ \(automationError)")
                .font(.system(size: Typography.caption))
                .foregroundStyle(.orange)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xs)
        }
    }

    /// 自动规则（内容复用原 rulesBlock；信息流全宽卡）
    @ViewBuilder
    private var rulesBlock: some View {
        // v3.9.21：自动规则（条件触发）——规则本体在后端 rules_engine：时间窗/HA 实体/上报事件
        // 命中且过冷却才执行；App 只负责列出、开关、删除（新建走对话/快捷指令，不在 App 里堆表单）
        if !rules.isEmpty {
            VStack(spacing: 10) {
                ForEach(rules) { r in
                    RuleRow(item: r,
                            onToggle: { on in
                                Task {
                                    _ = await auth.toggleRule(id: r.id, enabled: on)
                                    await loadRules()   // 无论成败都回读，避免开关显示与后端不一致
                                }
                            },
                            onDelete: { pendingRuleDelete = r })
                }
            }
            .padding(Spacing.xl)
            .dashboardCard()
            .accessibilityLabel("自动规则，\(rules.count) 条")
        }
    }

    /// 服务状态（原 NAS 面板网格；路由器状态并入本区一行，原 routerBlock 删独立栏目）
    @ViewBuilder
    private var nasPanelBlock: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            // v3.9.46：CPU / 内存卡曾接详情弹窗；**v3.9.54 用户判掉**：「去掉CPU和内存卡片的弹窗，
            // 只显示卡片，点击不再弹窗」→ 摘掉 tapButton 与 zoom 源，sub 里那句"点击查看"一并改实话。
            MeterCard(name: "CPU", icon: "cpu.fill", value: nas.cpuText,
                      sub: "整机占用", ratio: nas.cpu / 100.0, color: .blue)
            MeterCard(name: "内存", icon: "memorychip.fill", value: nas.memUsedText,
                      sub: "/ \(nas.memTotalText)", ratio: nas.memPct, color: .green)
            ServiceCard(name: "Nori后端", icon: "server.rack", running: nas.qingliaoAlive, detail: "Docker 内存 \(nas.qingliaoDockerMemText)")
                .tapButton { activeSheet = .service }
                .matchedTransitionSource(id: DashboardSheet.service.id, in: sheetZoomNS)   // v3.9.0：卡片→详情 zoom
            ServiceCard(name: "智能体服务", icon: "sparkles", running: nas.hermesAlive, detail: nas.hermesMemText)
                .tapButton { activeSheet = .serviceHermes }
                .matchedTransitionSource(id: DashboardSheet.serviceHermes.id, in: sheetZoomNS)   // v3.9.0：卡片→详情 zoom
            // v2.0.72：Docker 管理卡片（点击弹部署弹窗）
            ServiceCard(name: "Docker", icon: "shippingbox.fill", running: dockerContainerCount > 0,
                        detail: dockerContainerCount > 0 ? "\(dockerContainerCount) 个容器 · 点击管理" : "暂无容器 · 点击部署")
                .tapButton { activeSheet = .docker }
                .matchedTransitionSource(id: DashboardSheet.docker.id, in: sheetZoomNS)   // v3.9.0：卡片→详情 zoom
            ServiceCard(name: "运行时间", icon: "clock.fill", running: true, detail: nas.uptime)
            // v2.0.86：硬件温度（CPU / NVMe）
            ServiceCard(name: "温度", icon: "thermometer", running: true, detail: hwDetail)
            // v3.4.13：磁盘汇总卡并入 NAS 面板网格（与温度卡等尺寸）；看板移除「系统盘」分区卡片栏目（分区已收进磁盘弹窗分组展示）
            MeterCard(name: "磁盘", icon: "internaldrive.fill", value: nas.maxDiskPctText, sub: "\(nas.disks.filter { $0.isSystem }.count) 系统盘 · \(nas.disks.filter { !$0.isSystem }.count) 数据卷 · 点击查看", ratio: nas.maxDiskPct / 100.0, color: .orange)
                .tapButton { activeSheet = .disks }
                .matchedTransitionSource(id: DashboardSheet.disks.id, in: sheetZoomNS)   // v3.9.0：卡片→详情 zoom
        }
        // w5：原 routerBlock 状态并入服务状态区一行（完整启停面板进弹窗，功能不丢）
        routerRow
    }

    /// 路由器状态行（原 routerBlock 的收敛形态；点击进完整面板弹窗）
    private var routerRow: some View {
        Button {
            Haptics.tap()
            activeSheet = .routerSheet
        } label: {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(router.clashRunning ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Image(systemName: "wifi.router")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("路由器")
                    .font(.system(size: Typography.subhead, weight: .medium))
                    .foregroundStyle(.primary)
                Text(routerStatusText)
                    .font(.system(size: Typography.caption))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: Typography.caption, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .dashboardCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("路由器，\(routerStatusText)，点击管理")
    }

    /// 路由器行副文案：有错说错，否则报 Clash 起停
    private var routerStatusText: String {
        if !router.error.isEmpty { return router.error }
        return router.clashRunning ? "Clash 运行中" : "Clash 已停止"
    }

    // MARK: - w5-4 动态信息流

    /// 任务执行记录（信息流全宽卡；完整管理在"自动化"弹窗，信息流只做概览行）
    @ViewBuilder
    private var taskFeedBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("任务执行记录")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if activeAutomationCount > 0 {
                    Text("\(activeAutomationCount) 个进行中")
                        .font(.system(size: Typography.caption))
                        .foregroundStyle(.tertiary)
                }
            }
            if automations.isEmpty {
                Text("暂无待执行的任务")
                    .font(.system(size: Typography.subhead))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, Spacing.xs)
            } else {
                // 按执行时间排序（最近到点的在前）
                let feed = automations.sorted { $0.runAt < $1.runAt }
                ForEach(feed) { a in
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(a.runAt > Date() ? Color.orange : Color.secondary)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.name)
                                .font(.system(size: Typography.subhead, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(feedRemainText(a))
                                .font(.system(size: Typography.caption))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: Typography.caption, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .tapButton { activeSheet = .automationSheet }
                    .padding(.vertical, Spacing.xs)
                    if a.id != feed.last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
        .padding(Spacing.xl)
        .dashboardCard()
        .accessibilityLabel("任务执行记录，\(activeAutomationCount) 个进行中")
    }

    /// 连接器动态（内容复用原 connectorsBlock；信息流全宽卡，点击进连接器面板）
    @ViewBuilder
    private var connectorsBlock: some View {
        // v3.9.74 P1.5 连接器面板（Muse 借鉴）：MCP 工具 + 智能家居 + 生活卡片 收拢总览。
        // 不重复实现功能，状态总览 + 直达入口：点卡片 → 面板关闭 → 再弹对应设置页。
        Button {
            Haptics.tap()
            activeSheet = .connectorPanel
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "rectangle.connected.to.line.2")
                    .font(.system(size: Typography.title))
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("连接器动态")
                        .font(.system(size: Typography.subhead, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("工具服务 · 智能家居 · 生活卡片")
                        .font(.system(size: Typography.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("AI 已接入的数字生活总览与入口")
                        .font(.system(size: Typography.caption))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: Typography.caption))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.xl)
        }
        .buttonStyle(.plain)
        .dashboardCard()
        .accessibilityLabel("连接器动态，点击查看工具服务总览")
    }

    /// 用量一行（原 usageBlock + tokenUsageBlock 合并；长按重置 token 统计的能力保留）
    @ViewBuilder
    private var usageRowBlock: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: Typography.title))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("用量")
                    .font(.system(size: Typography.subhead, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(usageSummaryText)
                    .font(.system(size: Typography.body, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.xl)
        .dashboardCard()
        // v3.9.85：长按重置 token 统计（能力从 TokenUsageCard 搬过来，入口不丢）
        .onLongPressGesture(minimumDuration: 0.5) {
            guard tokenUsage != nil else { return }
            Haptics.medium()
            showUsageResetConfirm = true
        }
        .confirmationDialog("重置 token 用量统计？\n从现在起重新累计，今日/本月旧账清零。",
                            isPresented: $showUsageResetConfirm, titleVisibility: .visible) {
            Button("重置统计", role: .destructive) { Task { await resetTokenUsage() } }
            Button("取消", role: .cancel) {}
        }
        .accessibilityLabel("用量。\(usageSummaryText)。长按可重置统计")
    }

    /// 用量一行文案：Token 今日/本月 + 模型服务个数；加载失败说实话
    private var usageSummaryText: String {
        if let u = tokenUsage {
            let base = "Token 今日 \(u.today.totalM) · 本月 \(u.month.totalM)"
            if providerUsages.isEmpty { return base }
            return base + " · \(providerUsages.count) 个模型服务"
        }
        if !tokenUsageError.isEmpty { return tokenUsageError }
        if !usageError.isEmpty { return usageError }
        return "加载中…"
    }

    // MARK: - 数据

    // v2.0.86：硬件温度状态
    @State private var hwCpu: Double?
    @State private var hwSsd: Double?
    // v2.0.87u：天气
    @State private var weatherTemp: Double?
    @State private var weatherCode: Int?
    @State private var weatherCity = UserDefaults.standard.string(forKey: "qingliao_weather_city") ?? ""   // v2.0.87am：手动城市

    /// v3.0.22：硬件温度（保留 View 层因需 @State hwCpu/hwSsd 驱动刷新）
    private var hwDetail: String {
        let c = hwCpu.map { String(format: "CPU %.0f°C", $0) } ?? "CPU --"
        let s = hwSsd.map { String(format: "SSD %.0f°C", $0) } ?? "SSD --"
        return "\(c) · \(s)"
    }

    private func loadHw() async {
        if let j = await auth.jsonOrLog("/api/hw/status") {
            hwCpu = j["cpu_temp"] as? Double
            hwSsd = j["ssd_temp"] as? Double
        }
    }

    // v2.0.87u：天气加载（后端缓存 30 分钟）
    // v2.0.118 fix：带城市参数（原无 city 走 IP 定位——NAS 出口无公网 IP 定位失败 → temp null 不显示温度）
    // v3.9.25：删掉原无参 loadWeather()——零调用点（死代码），且它是仓内第 3 份手写
    //   /api/weather 解析；解析统一走 WeatherService.parseBackend（见下方 loadWeatherWithCity）

    // v2.0.87am：手动城市名 → 天气（未设置城市不显示徽章）
    // v3.9.46：先查进程内天气缓存——看板每次切回、弹窗每次关闭都不再重打 /api/weather
    private func loadWeatherWithCity() async {
        weatherCity = UserDefaults.standard.string(forKey: "qingliao_weather_city") ?? ""
        guard !weatherCity.isEmpty else {
            weatherTemp = nil
            weatherCode = nil
            return
        }
        let key = weatherCity          // 缓存键固定用用户存的城市原名（下面会把 weatherCity 换成后端回的名字）
        if let hit = WeatherCache.value(city: key) {
            weatherTemp = hit.temp
            weatherCode = hit.code
            if !hit.city.isEmpty { weatherCity = hit.city }
            return
        }
        let enc = weatherCity.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? weatherCity
        if let j = await auth.jsonOrLog("/api/weather?city=\(enc)") {
            // v3.9.25：改走 WeatherService.parseBackend —— 消除仓内第 3 份手写解析，
            // 并顺带拿到 num/int 的 NaN/超范围护栏（字段语义与旧写法一致）
            let s = WeatherService.parseBackend(j)
            WeatherCache.put(city: key, snap: s)
            weatherTemp = s.temp
            weatherCode = s.code
            if !s.city.isEmpty { weatherCity = s.city }
        }
    }

    private func loadRouter() async {
        if let j = await auth.jsonOrLog("/api/router/status") {
            router = RouterStatus.parse(j)
        } else {
            // v3.9.41（SR36）：原先 nil 就什么都不写 → 路由器连不上时卡片静默挂着上一轮的旧数字，
            // 用户以为还是实时值。失败要落到卡片下方那行红字上。
            router.error = "路由器状态获取失败"
        }
    }

    /// v3.0.36：模型使用量（DeepSeek/StepFun 余额 + unsupported 降级）
    private func loadProviderUsage() async {
        guard let j = await auth.jsonOrLog("/api/nas/providers-usage") else {
            usageError = "用量查询失败"
            return
        }
        if let ps = j["providers"] as? [[String: Any]] {
            let list = ps
            providerUsages = list.map { ProviderUsage.parse($0) }
            usageError = ""
        } else if let e = j["error"] as? String {
            usageError = e
        }
    }

    /// v3.9.82：token 用量（今日/本月，单位 M）——后端 /api/nas/token-usage 读 Hermes state.db
    private func loadTokenUsage() async {
        guard let j = await auth.jsonOrLog("/api/nas/token-usage") else {
            tokenUsageError = "token 用量查询失败"
            return
        }
        if let u = TokenUsage.parse(j) {
            tokenUsage = u
            tokenUsageError = ""
        } else if let e = j["error"] as? String, !e.isEmpty {
            tokenUsageError = e
        } else {
            tokenUsageError = "token 用量暂不可用"
        }
    }

    /// v3.9.85：长按用量行 → 重置统计（后端记重置起点，今日/本月旧账不再计入）
    private func resetTokenUsage() async {
        do {
            let (data, resp) = try await auth.request("/api/nas/token-usage-reset", method: "POST", body: [:])
            let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            guard resp.statusCode == 200, (j?["ok"] as? Bool) == true else {
                tokenUsageError = "重置失败，请重试"
                return
            }
            Haptics.notify(.success)
            await loadTokenUsage()
        } catch {
            tokenUsageError = "重置失败，请重试"
        }
    }

    /// 快捷指令：启动/关闭 Clash
    private func clashAction(_ action: String) {
        // v2.0.102：防抖——操作中再点直接忽略（原两个并发 Task 各自 defer 释放 busy 互相覆盖）
        // SR36：闸门挪到 @State clashBusy。原先存 `router.busy`，而本方法结尾必然 `await loadRouter()`
        // 整体替换 router（parse 出来的 busy 恒 false）、30s 轮询也会替换 → 闸门形同虚设，连点即并发下发。
        guard !clashBusy else { return }
        clashBusy = true
        Task {
            defer { clashBusy = false }
            var reqFailed = false
            if let j = await auth.jsonOrLog("/api/router/clash/\(action)", method: "POST", body: nil) {
                // v2.0.92：操作成功清空错误显示（失败原因由后端按"服务已启动"输出判断）
                if (j["ok"] as? Bool) == true {
                    router.error = ""
                }
                router = RouterStatus.merge(router, with: j)
            } else {
                reqFailed = true
            }
            await loadRouter()
            if reqFailed {
                // SR36：请求整个失败（非 2xx/超时）原先连一行提示都不留 → 「点了没反应」
                router.error = "Clash \(action == "start" ? "启动" : "关闭")请求失败"
            }
        }
    }

    /// v3.0.18：设备一键体检 —— w5：删独立卡，refresh 时自动拉取，只取 level/summary 进 Hero 一句话
    private func runDiagnose() async {
        if let j = await auth.jsonOrLog("/api/nas/diagnose") {
            diagnoseLevel = j["level"] as? String ?? ""
            diagnoseSummary = j["summary"] as? String ?? ""
        }
    }

    /// v3.9.21：自动规则（条件触发型；与上面"自动化"的延时型是两套）
    private func loadRules() async {
        rules = await auth.loadRules()
    }

    private func removeRule(_ r: RuleItem) async {
        if await auth.deleteRule(id: r.id) { await loadRules() }
    }

    private func refresh() async {
        // v3.9.41（SR39）：在途闸门。下拉刷新、30s 轮询、空态「刷新」按钮、执行场景后的补刷
        // 都调这里，原先无闸门 → 多份「8 路并发」同时在飞：蜂窝下成倍流量，且晚到的旧响应会把
        // 新值写回去（@State 逐个覆盖，没有序号判定）。重入直接返回——那一轮本来就会拿到新数据。
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        // v4.4.x item5①：聚合加载起跑即刷新鲜度（SessionsView 三秒节流同款口径：起跑记时，
        // 不等成功——失败也不让切回 Tab 时无脑重打）
        lastLoadAt = Date()
        // v3.0.x：并行请求——7 个独立 API 并发（原串行，每个等前一个完成才发下一个）
        // v3.0.81c：不用 TaskGroup+addTask{@MainActor}——Xcode 26.6 Swift 6 区域隔离检查器对
        // 「闭包捕获 self」的这种写法直接报编译错误（checker bug）。
        // 改为 MainActor 方法 + async let（Void 返回值无 Sendable 问题），语义同样是 7 路并发。
        async let nasTask: Void = loadNAS()
        async let haTask: Void = loadHA()
        async let scenesTask: Void = loadScenes()
        async let autosTask: Void = loadAutomations()
        async let sugTask: Void = loadSuggestionIfNeeded()
        async let routerTask: Void = loadRouter()
        async let usageTask: Void = loadProviderUsage()
        async let rulesTask: Void = loadRules()
        // v3.9.82：token 用量与其余 8 路并发（同一个在途闸门覆盖）
        async let tokenTask: Void = loadTokenUsage()
        // w5：体检并入 Hero 一句话 → refresh 时自动拉取（原先是用户手动点按钮才跑）
        async let diagTask: Void = runDiagnose()
        _ = await (nasTask, haTask, scenesTask, autosTask, sugTask, routerTask,
                   usageTask, rulesTask, tokenTask, diagTask)
    }

    /// NAS 状态
    private func loadNAS() async {
        if let n = await auth.jsonOrLog("/api/nas/status") {
            nas = NASStatus.parse(n)
        }
    }

    /// HA 设备状态
    private func loadHA() async {
        if let h = await auth.jsonArrayOrLog("/api/ha/states") {
            haEntities = h.compactMap { HAEntity.parse($0 as? [String: Any] ?? [:]) }
        }
    }

    // MARK: v3.9.46 安防布防 / 撤防

    /// 点击安防卡：先确认再下发（布防/撤防是会改变家庭安防状态的动作，误触代价高）
    private func requestArm(_ armed: Bool) {
        guard alarm != nil else {
            alarmError = "没找到网关警戒开关（guard_mode），无法布防/撤防"
            Haptics.error()
            return
        }
        guard !alarmBusy else { return }        // 在途连点直接吞（同 clashAction 的防抖口径）
        confirmArmTarget = armed
    }

    /// 真正下发：Aqara 网关警戒模式是个 switch 实体 ⇒ 走 HA 通用服务口
    /// POST /api/ha/services/switch/turn_on|turn_off（与 HADeviceSheet 控制灯/空调同一条通道）。
    /// 失败一定要出声（v3.9.41 在 HADeviceSheet 修过一次同样的"静默吞错"），
    /// 成功后立刻回读 /api/ha/states 让卡片显示真值，不做乐观更新。
    private func applyArm(_ armed: Bool) {
        guard let e = alarm else { return }
        alarmBusy = true
        let path = armed ? "/api/ha/services/switch/turn_on" : "/api/ha/services/switch/turn_off"
        Task {
            defer { alarmBusy = false }
            do {
                _ = try await auth.request(path, method: "POST", body: ["entity_id": e.entityID])
                Haptics.success()
            } catch {
                alarmError = "\(armed ? "布防" : "撤防")失败：\(error.localizedDescription)"
                Haptics.error()
            }
            await loadHA()
        }
    }

    /// confirmationDialog 的按钮单独抽出来：动态按钮塞进 body 大表达式里撞过类型检查超时
    /// （见 usageRestoreRow / ChatView.chatActionDialogContent 的同款处理）
    @ViewBuilder
    private var armDialogButtons: some View {
        Button(confirmArmTarget == true ? "确认布防" : "确认撤防",
               role: confirmArmTarget == true ? nil : .destructive) {
            if let t = confirmArmTarget { applyArm(t) }
            confirmArmTarget = nil
        }
        Button("取消", role: .cancel) { confirmArmTarget = nil }
    }

    private var armDialogMessage: String {
        confirmArmTarget == true
            ? "网关进入警戒模式后，门窗被打开会立即告警。"
            : "撤防后家中不再告警，请确认不是误触。"
    }

    /// 场景列表
    private func loadScenes() async {
        if let j = await auth.jsonOrLog("/api/scenes/list") {
            scenes = (j["scenes"] as? [[String: Any]] ?? []).map { SceneItem($0) }
        }
    }

    /// 自动化列表
    private func loadAutomations() async {
        if let j = await auth.jsonOrLog("/api/automations/list") {
            automations = (j["automations"] as? [[String: Any]] ?? []).map { AutomationItem($0) }
        }
    }

    /// 智能建议（v2.0.116 后端建议 + v2.0.132 缓存兜底 + 过期自动生成）
    private func loadSuggestionIfNeeded() async {
        guard smartSuggestion.isEmpty else { return }
        if let j = await auth.jsonOrLog("/api/agent/last_suggestion"),
           let sug = j["suggestion"] as? [String: Any],
           let text = sug["text"] as? String, !text.isEmpty {
            smartSuggestion = text
        } else if let cached = cachedSuggestion {
            smartSuggestion = cached
        } else if shouldAutoGenerate {
            Task { await loadSmartSuggestion() }
        }
    }

    // v2.0.132：智能建议缓存（30 分钟有效，避免每次进看板/轮询重复生成费 token）
    private var cachedSuggestion: String? {
        guard let raw = UserDefaults.standard.string(forKey: "qingliao_suggestion_cache"),
              let ts = UserDefaults.standard.object(forKey: "qingliao_suggestion_cache_ts") as? Date,
              Date().timeIntervalSince(ts) < 1800 else { return nil }
        return raw
    }

    private var shouldAutoGenerate: Bool {
        cachedSuggestion == nil   // 无有效缓存 → 需要自动生成
    }

    /// v2.0.116：生成智能建议（天气 + NAS + 设备状态 → Agent）
    private func loadSmartSuggestion() async {
        guard !smartLoading else { return }
        smartLoading = true
        defer { smartLoading = false }
        var parts: [String] = []
        if let t = weatherTemp {
            parts.append("天气：\(weatherCity.isEmpty ? "当前城市" : weatherCity) \(Int(t))°C 码\(weatherCode ?? 0)")
        }
        parts.append("NAS：CPU \(Int(nas.cpu))% 内存 \(Int(nas.memUsed))G/\(Int(nas.memTotal))G 磁盘 \(Int(nas.maxDiskPct))%")
        if !haEntities.isEmpty {
            let lightsOn = haEntities.filter { $0.entityID.hasPrefix("light.") && $0.state == "on" }.count
            let acOn = haEntities.filter { $0.entityID.hasPrefix("climate.") && $0.state == "on" }.count
            parts.append("设备：\(lightsOn) 盏灯开 / \(acOn) 台空调开")
        }
        if let j = await auth.jsonOrLog("/api/agent/suggest", method: "POST",
                                        body: ["context": parts.joined(separator: "；")]),
           let text = j["text"] as? String, !text.isEmpty {
            smartSuggestion = text
            // v2.0.132：生成成功写缓存（30 分钟有效，轮询不重复生成）
            UserDefaults.standard.set(text, forKey: "qingliao_suggestion_cache")
            UserDefaults.standard.set(Date(), forKey: "qingliao_suggestion_cache_ts")
        } else {
            smartSuggestion = "建议生成失败，请重试"
        }
    }

    /// v2.0.104：取消自动化（长按卡片）
    /// v3.9.41（SR38）：原先 `_ = await jsonOrLog(...)` 丢弃返回值就本地摘除——后端没删成时
    /// 30s 轮询把它原样拉回，用户以为已取消、到点照样执行场景。现按响应走：成功用后端列表覆盖。
    private func cancelAutomation(_ a: AutomationItem) {
        automationError = ""
        Task {
            do {
                let j = try await auth.json("/api/automations/\(a.id)", method: "DELETE", body: nil)
                guard (j["ok"] as? Bool) ?? false else {
                    automationError = "取消失败：\(j["message"] as? String ?? "服务器未删除")"
                    return
                }
                if let list = j["automations"] as? [[String: Any]] {
                    automations = list.map { AutomationItem($0) }
                } else {
                    automations.removeAll { $0.id == a.id }
                }
            } catch {
                automationError = "取消失败：\(error.localizedDescription)"
            }
        }
    }

    /// v2.0.96：执行场景（v2.0.102：加防抖——连点不重复执行）
    /// v2.0.113：含危险动作（布防/开关类非灯设备）时先弹确认防误触
    private func runScene(_ s: SceneItem) {
        guard !sceneRunning else { return }
        if hasDangerousAction(s) {
            confirmSceneRun = s
        } else {
            executeScene(s)
        }
    }

    /// v2.0.113：危险动作判断（布防/离家/断电类场景名，误触代价高）
    private func hasDangerousAction(_ s: SceneItem) -> Bool {
        let name = s.name
        return name.contains("布防") || name.contains("离家") || name.contains("断电")
            || name.contains("关闭所有") || name.contains("总闸")
    }

    /// v2.0.113：实际执行（确认后或非危险场景）
    private func executeScene(_ s: SceneItem) {
        sceneRunning = true
        Task {
            defer { sceneRunning = false }
            if let j = await auth.jsonOrLog("/api/scenes/run", method: "POST", body: ["name": s.name]) {
                let ok = (j["ok"] as? Bool) ?? false
                let msg = (j["message"] as? String) ?? (ok ? "执行成功" : "执行失败")
                sceneResult = msg
                showSceneResult = true
                // v2.0.113：执行后刷新（结果推送微信后卡片状态同步）
                Task { await refresh() }
            } else {
                sceneResult = "执行失败（网络错误）"
                showSceneResult = true
            }
        }
    }

    /// v2.0.96：删除场景（v2.0.102：仅服务器确认成功才移除——失败保留并提示）
    private func deleteScene(_ s: SceneItem) {
        Task {
            if let j = await auth.jsonOrLog("/api/scenes/delete", method: "POST", body: ["name": s.name]),
               (j["ok"] as? Bool) == true {
                scenes.removeAll { $0.name == s.name }
            } else {
                sceneResult = "删除失败（网络或服务器错误）"
                showSceneResult = true
            }
        }
    }

    // MARK: - v2.0.72 Docker 容器数量

    private func loadDockerCount() async {
        if let j = await auth.jsonOrLog("/api/docker/ps") {
            dockerContainerCount = (j["containers"] as? [[String: Any]] ?? []).count
        }
    }

    // MARK: - HA 派生（与 PWA 相同挑选规则）

    private var lights: [HAEntity] {
        // 过滤指示灯（NAS 查询指示灯等不参与灯列表，改由 switch 开关实体控制）
        haEntities.filter {
            $0.entityID.hasPrefix("light.") && !$0.state.contains("unavailable")
                && !$0.entityID.contains("indicator_light")
        }
    }
    private var lightsOn: Int { lights.filter { $0.state != "off" }.count }
    private var haLights: String { "\(lightsOn)/\(lights.count) 盏" }

    private var climates: [HAEntity] {
        haEntities.filter { $0.entityID.hasPrefix("climate.") && !["unavailable", "offline", "unknown"].contains($0.state) }
    }
    private var climateOn: Int { climates.filter { $0.state != "off" }.count }
    private var haClimate: String { "\(climateOn)/\(climates.count) 台" }

    private var lockBattery: HAEntity? {
        haEntities.first { $0.entityID.contains("bacn01") && $0.entityID.contains("battery_level") }
    }
    private var haLockBattery: String {
        guard let e = lockBattery, let v = Double(e.state) else { return "--" }
        return "\(Int(v.rounded()))%"
    }

    private var doorbellBattery: HAEntity? {
        haEntities.first { $0.entityID.contains("chuangmi") && $0.entityID.contains("battery_level") }
    }
    private var haDoorbellBattery: String {
        guard let e = doorbellBattery, let v = Double(e.state) else { return "--" }
        return "\(Int(v.rounded()))%"
    }
    private var haDoorbellOnline: Bool {
        !(doorbellBattery?.state.contains("unavailable") ?? true)
    }

    // v3.9.19：安防数据源改为 Aqara 网关「警戒模式」开关
    // （用户已移除萤石插件，原 sensor.she_xiang_tou_alarmstatus 不复存在；
    //   后端 ha_proxy._keep_entity 已同步放行 guard_mode，否则 App 收不到这个实体）
    private var alarm: HAEntity? {
        haEntities.first { $0.entityID.contains("guard_mode") }
    }
    private var haAlarmArmed: Bool {
        guard let st = alarm?.state else { return false }
        return ["on", "布防", "armed", "armed_home", "armed_away"].contains(st)
    }
    /// 开关的 on/off 映射成中文（原 alarmstatus 的 state 本身就是中文，可直接显示）
    private var haAlarm: String {
        guard let st = alarm?.state else { return "--" }
        if st.isEmpty || st.contains("unavailable") { return "离线" }
        return haAlarmArmed ? "布防" : "撤防"
    }

    private var tempSensor: HAEntity? {
        // 优先室内温度计，其次任意 temperature sensor
        if let e = haEntities.first(where: { $0.entityID.contains("indoor_temperature") }) { return e }
        return haEntities.first {
            $0.entityID.hasPrefix("sensor.") && $0.entityID.contains("temperature")
                && !$0.state.contains("unavailable") && Double($0.state) != nil
        }
    }
    private var haTemp: String {
        guard let e = tempSensor, let v = Double(e.state) else { return "--" }
        return String(format: "%.1f°", v)
    }

    // MARK: v3.9.46 卡片详情弹窗的数据切片（都在已轮询的 haEntities 里挑，零新接口）

    /// 实体是否"可用"（v3.9.54 收口，用户：「只保留可用卡片，离线卡片不显示」）：
    /// 三张设备弹窗（门锁/猫眼/温度）共用这一条判定。HA 的离线是**状态串**而不是独立标记，
    /// 常见三种写法都要认（`unavailable` / `offline` / `unknown`），口径同既有 `climates` 过滤。
    private func isAvailable(_ e: HAEntity) -> Bool {
        let st = e.state
        return !st.isEmpty && !st.contains("unavailable")
            && !["offline", "unknown"].contains(st)
    }

    /// v3.9.74 P1.5 连接器面板：可用实体总数（与 isAvailable 同口径，只读已轮询数据零新请求）
    /// w5：同时是 Hero「在线设备」与设备文件夹计数的口径
    private var haAvailableCount: Int {
        haEntities.filter(isAvailable).count
    }

    /// v3.9.74 P1.5：连接器面板关闭后要接着弹的设置页（防 sheet 叠 sheet，dismiss 后再弹）
    @State private var pendingSheetAfterPanel: AfterPanelSheet?
    // v3.9.74c：面板关闭后真正呈现在弹的设置页（与 pending 意图分开，防 dismiss/present 同帧抖动）
    @State private var presentedAfterPanel: AfterPanelSheet?
    enum AfterPanelSheet: String, Identifiable {
        case mcp, lifeCards, mail, cloudDrive
        var id: String { rawValue }
    }

    /// 门锁相关实体：门锁本体（bacn01）+ lock 域 + 门磁一类含 door_lock 的实体。
    /// v3.9.54：再叠一层 `isAvailable` —— 离线的实体不进弹窗（用户点名）。
    /// ⚠️ 实际能到这里的不多：后端 `ha_proxy._keep_entity` 只放行 `(bacn01|chuangmi) + battery_level`
    ///    这类少数实体，`lock.*` 域根本没下发，所以这张弹窗目前基本只有"门锁电量"一枚卡。
    ///    要弹窗里出现锁体开关量，得先放宽后端白名单（那是后端改动，不在本轮）。
    private var lockEntities: [HAEntity] {
        haEntities.filter {
            ($0.entityID.contains("bacn01")
                || $0.entityID.hasPrefix("lock.")
                || $0.entityID.contains("door_lock"))
                && isAvailable($0)
        }
        .sorted { $0.entityID < $1.entityID }
    }

    /// 猫眼 / 门铃：**只保留「小白智能猫眼」这台设备自己的实体**（v3.9.54 用户点名）。
    /// 原来写的是 `contains("chuangmi") || contains("doorbell")` —— 创米（chuangmi）是品牌名，
    /// 家里那枚**创米小白智能插座** `switch.chuangmi_cn_237985068_m3_on_p_2_1`
    /// 也是 chuangmi，于是被一起拽进弹窗，看着就是"猫眼弹窗里有个不相干的东西"。
    /// 现在：品牌命中后还要过两道排除（开关域、插座型号 `_m3_` / `on_p_2_1` / `plug`），
    /// 并滤掉离线实体。
    private var doorbellEntities: [HAEntity] {
        haEntities.filter {
            ($0.entityID.contains("chuangmi") || $0.entityID.contains("doorbell")
                || $0.friendlyName.contains("猫眼"))
                && !isDoorbellPlug($0.entityID)
                && isAvailable($0)
        }
        .sorted { $0.entityID < $1.entityID }
    }

    /// 创米小白**插座**（不是猫眼）：开关域本体 + 它的子通道/电量传感器一律算插座。
    /// 插座实体名里带 `_m3_`（型号 M3）或 `on_p_2_1`（miio 通道），据此识别。
    private func isDoorbellPlug(_ id: String) -> Bool {
        id.hasPrefix("switch.") || id.contains("_m3_") || id.contains("on_p_2_") || id.contains("_plug")
    }

    /// 全部可用的温度计（卡片只显室内那一个，弹窗列各房间）
    private var roomTempEntities: [HAEntity] {
        haEntities.filter {
            $0.entityID.hasPrefix("sensor.")
                && $0.entityID.contains("temperature")
                && Double($0.state) != nil
                && isAvailable($0)
        }
        .sorted { $0.friendlyName < $1.friendlyName }
    }

    /// 安防卡副标题：没有 guard_mode 实体时要说实话，别写"点击布防"骗人
    private var alarmSub: String {
        if alarm == nil { return "未找到网关警戒开关" }
        if alarmBusy { return "正在下发…" }
        return haAlarmArmed ? "布防中 · 点击撤防" : "已撤防 · 点击布防"
    }

    // MARK: - v3.9.100+ 弹窗与刷新逻辑

    /// activeSheet 弹窗内容（原 body 内 `.sheet(item:onDismiss:)` 的 switch）
    @ViewBuilder
    private func sheetContent(for s: DashboardSheet) -> some View {
        switch s {
        case .lights:
            HADeviceSheet(title: "客厅灯", domain: "light")
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: DashboardSheet.lights.id, in: sheetZoomNS))   // v3.9.0
        case .climate:
            HADeviceSheet(title: "空调", domain: "climate")
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: DashboardSheet.climate.id, in: sheetZoomNS))   // v3.9.0
        case .service:
            ServiceControlSheet(service: .qingliao)
                .presentationDetents([.medium])
                .navigationTransition(.zoom(sourceID: DashboardSheet.service.id, in: sheetZoomNS))   // v3.9.0
        case .serviceHermes:
            ServiceControlSheet(service: .hermes)
                .presentationDetents([.medium])
                .navigationTransition(.zoom(sourceID: DashboardSheet.serviceHermes.id, in: sheetZoomNS))   // v3.9.0
        case .disks:
            DisksSheet(disks: nas.disks)
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: DashboardSheet.disks.id, in: sheetZoomNS))   // v3.9.0
        case .docker:
            DockerSheet()
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: DashboardSheet.docker.id, in: sheetZoomNS))   // v3.9.0
        // v3.9.46：三张设备详情弹窗（统一 BoardSheetHeader 头部、统一 medium/large detents、
        // 统一 zoom 转场 —— 用户要求"弹窗样式统一"）
        // v3.9.54：卡形换成抄磁盘分区卡（两列网格），**离线实体不再列进来**，
        // 所以计数文案改成"可用"（口径见 DashboardView.isAvailable）
        case .lock:
            HADeviceDetailSheet(title: "门锁",
                                detail: "\(lockEntities.count) 个可用实体",
                                entities: lockEntities,
                                emptyTitle: "门锁现在没有可用实体",
                                emptySubtitle: "离线实体不列（v3.9.54）；门锁电量来自 "
                                    + "/api/ha/states（看板 30s 轮询），若刚换过电池或重新配网，"
                                    + "下拉看板重取一次")
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: DashboardSheet.lock.id, in: sheetZoomNS))
        case .temps:
            HADeviceDetailSheet(title: "各房间温度",
                                detail: "\(roomTempEntities.count) 个温度计",
                                entities: roomTempEntities,
                                emptyTitle: "没有读到温度传感器",
                                emptySubtitle: "看板卡片只取一个室内温度，这里列全所有 temperature 实体")
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: DashboardSheet.temps.id, in: sheetZoomNS))
        case .doorbell:
            HADeviceDetailSheet(title: "猫眼",
                                detail: "\(doorbellEntities.count) 个可用实体",
                                entities: doorbellEntities,
                                emptyTitle: "没有读到猫眼的实体",
                                emptySubtitle: "这里只列小白智能猫眼自己的实体（创米插座已排除）；"
                                    + "画面快照后端未透出，离线实体也不列")
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: DashboardSheet.doorbell.id, in: sheetZoomNS))
        // v3.9.54：CPU / 内存弹窗已删（用户：只显示卡片，点击不再弹窗）
        case .weather:
            // v3.9.25：两页天气弹窗（今天 / 未来 5 天）。默认半屏 medium（用户定稿）；
            // 保留 .large 作逃生口：第 2 页是纯 VStack（无 ScrollView），小屏若超出一行会被静默裁切。
            WeatherSheet(mode: .local)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onAppear { weatherSheetShown = true }
                .navigationTransition(.zoom(sourceID: DashboardSheet.weather.id, in: sheetZoomNS))
        case .connectorPanel:
            // v3.9.74 P1.5 连接器面板：MCP + 智能家居 + 生活卡 收拢总览（Muse 借鉴）。
            // 面板内跳转走本页已有 sheet 机制；MCP/生活卡设置弹窗在面板 dismiss 后弹出（防 sheet 叠 sheet）。
            ConnectorPanelSheet(
                onOpenMCP: { activeSheet = nil; pendingSheetAfterPanel = .mcp },
                onOpenLifeCards: { activeSheet = nil; pendingSheetAfterPanel = .lifeCards },
                onOpenMail: { activeSheet = nil; pendingSheetAfterPanel = .mail },
                onOpenCloudDrive: { activeSheet = nil; pendingSheetAfterPanel = .cloudDrive },
                haCount: haAvailableCount,
                sceneCount: scenes.count,
                automationCount: automations.count,
                ruleCount: rules.count)
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: DashboardSheet.connectorPanel.id, in: sheetZoomNS))
        // w5：文件夹式入口弹窗（内容复用原栏目 block，不新造管理界面）
        case .sceneSheet:
            VStack(spacing: 0) {
                BoardSheetHeader(title: "智慧场景", detail: "\(scenes.count) 个")
                ScrollView {
                    scenesContent
                        .padding(.horizontal, Spacing.sheetInset)
                        .padding(.bottom, Spacing.section)
                }
            }
            .presentationDetents([.medium, .large])
            .navigationTransition(.zoom(sourceID: DashboardSheet.sceneSheet.id, in: sheetZoomNS))
        case .deviceSheet:
            VStack(spacing: 0) {
                BoardSheetHeader(title: "智能家居", detail: "\(haAvailableCount) 台在线")
                ScrollView {
                    homeDevicesContent
                        .padding(.horizontal, Spacing.sheetInset)
                        .padding(.bottom, Spacing.section)
                }
            }
            .presentationDetents([.medium, .large])
            .navigationTransition(.zoom(sourceID: DashboardSheet.deviceSheet.id, in: sheetZoomNS))
        case .automationSheet:
            VStack(spacing: 0) {
                BoardSheetHeader(title: "自动化", detail: "\(automations.count) 个")
                ScrollView {
                    automationsContent
                        .padding(.horizontal, Spacing.sheetInset)
                        .padding(.bottom, Spacing.section)
                }
            }
            .presentationDetents([.medium, .large])
            .navigationTransition(.zoom(sourceID: DashboardSheet.automationSheet.id, in: sheetZoomNS))
        case .routerSheet:
            // w5：原 routerBlock 栏目收敛为服务状态区一行；完整启停面板搬进本弹窗（功能不丢）
            VStack(spacing: 0) {
                BoardSheetHeader(title: "路由器")
                RouterPanel(router: router,
                            busy: clashBusy,
                            onStart: { clashAction("start") },
                            onStop: { clashAction("stop") },
                            onRefresh: { Task { await loadRouter() } })
                    .padding(.horizontal, Spacing.sheetInset)
                    .padding(.bottom, Spacing.section)
            }
            .presentationDetents([.medium])
            .navigationTransition(.zoom(sourceID: DashboardSheet.routerSheet.id, in: sheetZoomNS))
        case .todoSheet:
            // w5：今日待办 = 既有速记弹窗（DockTabView 长按菜单「今日待办」同款），不新造页
            QuickCaptureSheet(mode: .todo)
        }
    }

    /// 看板 sheet 关闭后的收尾：刷新天气徽章 / 消费面板跳转意图
    private func dashboardSheetDismiss() {
        // v3.9.25：只在**天气弹窗**关闭后刷新徽章（弹窗内换城市写 UserDefaults，此处重读）。
        // 早先无条件刷新 → 关灯/空调/磁盘/docker 弹窗也各多打一次 /api/weather，
        // 且 weatherCity 会先被重置回 UserDefaults 原值，城市名会闪一下。
        if weatherSheetShown {
            weatherSheetShown = false
            Task { await loadWeatherWithCity() }
        }
        // v3.9.74c P1.5：连接器面板关闭（dismiss 已完成）后再弹 MCP/生活卡设置页。
        // 回调只关面板+记意图；这里消费意图，async 一帧错开 dismiss 收尾，防 present 请求被静默吞。
        if let p = pendingSheetAfterPanel {
            pendingSheetAfterPanel = nil
            DispatchQueue.main.async { presentedAfterPanel = p }
        }
    }

    /// 看板生命周期：首刷全套 + 30s 轮询（隐藏页 task 取消即停）
    /// v4.4.x item5：① 首刷全量、之后按新鲜度走（lastLoadAt 比对）；② 轮询只在有进行中任务时跑
    private func dashboardTask() async {
        guard isActive else { return }   // 隐藏态不启动（首次在非看板 tab 时无空转）
        // item5①：距上次聚合加载不足 30s → 整批跳过（@State 一个不碰 = 零网络、零重绘）。
        // 下拉刷新/空态刷新按钮/场景执行补刷照常走 refresh()（同样刷新鲜度）。
        var batchStale = true
        if let last = lastLoadAt {
            batchStale = Date().timeIntervalSince(last) >= Self.dashboardFreshness
        }
        if batchStale {
            // v2.0.86：硬件温度（CPU / NVMe）首屏加载
            await loadHw()
            // 首刷全套（首次进入 / 距上次全量超 30s 的切回——等效原 onAppear + Refresh 通知）
            await refresh()
            await loadDockerCount()
            await loadWeatherWithCity()
        }
        // 30s 自动刷新（v2.0.87c：10→30s，省电省流量，看板数据变化不敏感）
        // v2.0.133f：仅看板可见时刷——隐藏页轮询会抢 TabView 切页动画帧（isActive 变 false → task 取消即停）
        // item5②：只在有未到期的自动化（进行中任务）时轮询；无任务直接停，下次切回 task 重启
        while !Task.isCancelled {
            guard automations.contains(where: { $0.runAt > Date() }) else { break }
            try? await Task.sleep(for: .seconds(30))
            await refresh()
            await loadHw()
        }
    }

}


// MARK: - v4.0.50 启动链类型折叠（防启动期 demangler 递归爆主线程 1MB 栈）
//
// 事故与 ChatView 同源（见 ChatView.swift 末段 v4.0.49 复盘）：本页 body 的 mangled 类型名
// 实测 2033 字符（dSYM 符号表量出）≈ 1.0MB 主线程栈，正好压在崩线附近。危险量是**名字的字符数**，
// 不是元组嵌套层数 —— body 里内联的每条修饰器（尤其 sheet 的 switch、alert 的按钮闭包）
// 都会把整棵闭包类型压进父类型名。
//
// 修法 = 把 body 里过长的修饰器链折成具名 ViewModifier 分组：父类型名里只剩组名，链在各组
// 自己的 applyXxx 调用里解析（各自一次 1MB 栈预算）。
// ⚠️ 视图树、修饰器**种类/数量/顺序/参数**一律逐字未变（等价重构）；谁也不许把这些链再内联回
//    body —— 改链请改这里的 applyXxx，别动调用点。
extension DashboardView {

    /// 折叠组 1（4 条修饰器）：滚动定位 / 下拉刷新 / 两张 sheet 通道
    /// w5：卡片编辑器 sheet 已随固定结构移除
    @MainActor
    private func applyDashboardScrollChrome<C: View>(to content: C) -> some View {
        content
            .scrollPosition($scrollPos)
            // v2.0.86h：Dock 滑动隐藏已删除（从未生效，手动开关替代）
            .refreshable {
                await refresh()
            }
            .sheet(item: $activeSheet, onDismiss: dashboardSheetDismiss) { s in
                sheetContent(for: s)
            }
            // v3.9.74 P1.5：连接器面板里点「MCP 工具服务」「生活卡片」→ 面板关闭后再弹对应设置页
            // （呈现由上面 onDismiss 消费 pendingSheetAfterPanel 驱动；sheet(item:) 随置 nil 关闭）
            .sheet(item: $presentedAfterPanel) { target in
                switch target {
                case .mcp:
                    MCPSettingsSheet()
                        .presentationDetents([.medium, .large])
                case .lifeCards:
                    LifeCardsSettingsView()
                        .presentationDetents([.medium, .large])
                // v4.0.x 第 3 项：接入中心一页新增两个直达口（邮件 / 网盘）。
                // 复用设置页里那同一份 sheet，**不新做一套 UI**（用户口径：
                // 同一个功能只能有一个界面，双模式/双入口各做一套=埋雷）。
                case .mail:
                    MailSettingsSheet()
                        .presentationDetents([.medium, .large])
                case .cloudDrive:
                    CloudDriveSettingsSheet()
                        .presentationDetents([.medium, .large])
                }
            }
    }

    /// 折叠组 2（5 条修饰器）：3 条 alert + 2 条 confirmationDialog（危险动作方言）
    @MainActor
    private func applyDashboardDialogChrome<C: View>(to content: C) -> some View {
        content
            // v3.9.21：删除规则确认
            .alert("删除这条规则？", isPresented: Binding(
                get: { pendingRuleDelete != nil },
                set: { if !$0 { pendingRuleDelete = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let r = pendingRuleDelete { Task { await removeRule(r) } }
                    pendingRuleDelete = nil
                }
                Button("取消", role: .cancel) { pendingRuleDelete = nil }
            } message: {
                Text(pendingRuleDelete?.name ?? "")
            }
            // v2.0.96：场景执行结果提示
            .alert("场景执行结果", isPresented: $showSceneResult) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(sceneResult)
            }
            // v2.0.113：危险场景执行确认（布防/离家/断电类防误触）
            .confirmationDialog("确认执行场景？",
                                isPresented: Binding(get: { confirmSceneRun != nil },
                                                     set: { if !$0 { confirmSceneRun = nil } }),
                                titleVisibility: .visible) {
                Button("执行") {
                    if let s = confirmSceneRun {
                        executeScene(s)
                    }
                    confirmSceneRun = nil
                }
                Button("取消", role: .cancel) { confirmSceneRun = nil }
            } message: {
                Text("场景「\(confirmSceneRun?.name ?? "")」包含安全相关动作（布防/离家/断电），执行后可能改变家庭安防状态。")
            }
            // v3.9.46：安防卡点击布防/撤防的确认（同一套危险动作方言：confirmationDialog + 明示后果）
            .confirmationDialog("确认变更安防状态？",
                                isPresented: Binding(get: { confirmArmTarget != nil },
                                                     set: { if !$0 { confirmArmTarget = nil } }),
                                titleVisibility: .visible) {
                armDialogButtons
            } message: {
                Text(armDialogMessage)
            }
            // v3.9.46：布防/撤防的失败回执（原来这类写操作失败只会被 catch 吞掉）
            .alert("安防操作", isPresented: Binding(get: { !alarmError.isEmpty },
                                                    set: { if !$0 { alarmError = "" } })) {
                Button("知道了", role: .cancel) { alarmError = "" }
            } message: {
                Text(alarmError)
            }
    }

    @MainActor
    private struct DashboardScrollChrome: ViewModifier {
        let host: DashboardView

        func body(content: Content) -> some View { host.applyDashboardScrollChrome(to: content) }
    }

    @MainActor
    private struct DashboardDialogChrome: ViewModifier {
        let host: DashboardView

        func body(content: Content) -> some View { host.applyDashboardDialogChrome(to: content) }
    }
}
