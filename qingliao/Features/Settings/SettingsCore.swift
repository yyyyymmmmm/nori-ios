// 本文件由 2026-09-27 工程治理「Settings 物理合并」生成：多份同域设置页文件合并为一，
// UI 入口与行为零改动，仅文件边界变化。合并前各文件的来源见下方 MARK 分段。

import Combine
import Foundation
import LocalAuthentication
import PDFKit
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: ===== 以下原为 Features/Settings/SettingsView.swift =====

// MARK: - 设置页（iOS 设置风格分组列表，全部功能行可用）

struct SettingsView: View {
    @Environment(AuthStore.self) var auth
    @Environment(\.dismiss) private var dismiss
    // v3.4.28：横屏限宽
    @Environment(\.horizontalSizeClass) private var hSizeSettings
    @AppStorage("qingliao_appearance") var appearance = "system"   // dark/light/system（默认跟随系统）
    /// v4.0.9 点击震动总开关（与 Haptics.enabledKey 同一个 key，两边共用勿各写一份）
    /// ⚠️ 必须放在 **struct 主体**（本行附近），不能放 extension ——
    /// extension 不许含存储属性，Archive 报 "extensions must not contain stored
    /// properties" + "declared inside an extension cannot have a wrapper"（-parse 查不出）。
    @AppStorage(Haptics.enabledKey) private var hapticsOn = true

    // v4.0.10（用户：「在设置里增加可以关掉首页快捷卡片功能」）：首页快捷卡片总开关。
    // 与聊天页绑同一个键（Core/HomeCardStore.enabledKey）→ 那边立刻跟着变。
    @AppStorage(HomeCardStore.enabledKey) private var homeCardsOn = HomeCardStore.enabledDefault

    // v2.0.83c：连接设置二级页（服务器地址/测试连接/会话存储位置收进二级）
    @State var showConnSettings = false
    @State var showPasswordSheet = false
    @State var showSecrets = false
    // v2.0.81：知识库页面
    @State var showKB = false
    @State var showSkills = false
    // v2.0.87：AI 记忆
    @State var showMemory = false
    @State var memoryCount = 0
    @State var showTasks = false
    @State var showLogs = false
    /// v4.0.61：搜索「钉一钉存储」直达——钉一钉存储行已搬进「连接设置」页（用户 2026-10-05），
    /// 本开关只负责「打开连接设置并让它自己把那颗 sheet 弹出来」，页内 UI 归 ConnSettingsView
    @State var connOpenPinPath = false
    @State var showAppearance = false   // v3.0.4：外观弹窗（与云端统一）
    // v3.9.82：桌面图标长按快捷方式（候选清单里自己挑 4 项显示；iOS 桌面长按菜单上限就是 4）
    // v4.0.x：候选已随 OrbQuickAction.all 长到 8 项 —— 候选列表是动态的（HomeShortcut.candidates），
    //         这里与弹窗都不许再写死项数。
    @State var showHomeShortcuts = false
    @AppStorage(HomeShortcutStore.defaultsKey) var homeShortcutsRaw = ""
    @State var scrollPos = ScrollPosition()
    // J 线 2026-10-06：模型管理独立页已删（模型切换并入「连接设置」）；
    // 微信通道模型已删（微信走「对接第三方」platforms）；权限与 AI 操控已拆入「连接应用」；
    // 能力示例（卡片画廊）整行删掉；微信推送开关删掉。
    @State var showAbout = false
    @State var confirmLogout = false   // v3.0.5 review fix：退出登录二次确认（与云端一致）
    @State var secretCount = 0
    @State var showHASettings = false
    // v3.5.0：MCP 工具服务管理弹窗
    @State var showMCPSettings = false
    // J 线 2026-10-06：新增页开关
    @State var showConnectApps = false
    @State var showThirdParty = false
    @State var showReadAloud = false
    // v4.0.x：邮件接入（IMAP/SMTP 邮箱账号，AI 可收发邮件）
    @State var showMailSettings = false
    // v4.0.x：网盘接入（夸克等官方 skill 包 + 授权码；用户口径=放设置，不进连接器面板）
    @State var showCloudDrive = false
    // v3.5.x：生活卡片设置（股票 / 资讯 / 快递）
    @State var showLifeCards = false
    // v3.9.32：一句话本地定时提醒 / 文件管理
    @State var showQuickReminder = false
    @State var showFilesManager = false
    // v3.0.17：聊天字体大小从一级菜单移除（外观二级菜单持有），fontSize 声明一并清理
    // v3.0.9：外观下天气城市已移除（天气城市设定在看板 WeatherBadge 点按处），相关状态一并清理
    // v2.0.101：Agent 使用说明内联展开
    @State var showAgentHelp = false
    // K 线 2026-10-06：智能路由/上下文压缩二级页（行内展开收进二级页）
    @State var showRoutingSettings = false
    @State var showContextCompress = false
    // v4.0.11：主动 Agent 设置弹窗（后端 proactive_agent：总开关/预算/静默/事件源/复盘）
    @State var showProactive = false
    // v2.0.105：Agent 关键词管理弹窗
    @State var showAgentKeywords = false
    // v2.0.113：Agent 记忆弹窗 + 计数
    @State var showAgentMemory = false
    @State var agentRuleCount = 0
    // v3.0.20：Agent 模型自定义（独立于主模型，可单独指定 Agent 使用的模型）
    // J 线 2026-10-06：Agent 模型独立页已删（一个功能一个入口，主模型在「连接设置」统一管理）；
    // UserDefaultsKey.agentModel / agentProvider 的 key 保留（ChatStore/AppIntents 仍在读）。
    @AppStorage(UserDefaultsKey.agentModel) var agentModel = ""
    @AppStorage(UserDefaultsKey.agentProvider) var agentProvider = ""
    // v2.0.116：执行历史弹窗
    @State var showHistory = false
    // v3.4.25：崩溃日志查看/导出弹窗
    // v3.6.0：原独立「崩溃日志」弹窗整合进「诊断」页（DiagnosticsView 内含崩溃日志分组），
    //         避免两个重复又可能互相矛盾的入口；本页不再单独持有该弹窗状态。
    @State var showDiagnostics = false
    // K 线 2026-10-06：本地模型整套删除（Hermes 是唯一后端，端侧模型是第二套模型体系）。
    // J 线 2026-10-06：能力示例（卡片画廊）整行删掉；微信推送开关删掉。
    // v3.0.81：上下文管理（v4.0.x：默认值与真源 ContextTuning.defaultThreshold 同源，勿再写字面量）
    @AppStorage("qingliao_context_auto_compress") var contextAutoCompress = false
    @AppStorage("qingliao_context_threshold") var contextThreshold = ContextTuning.defaultThreshold
    // v3.9.56：TypeSafe 智能路由（设置页开关 + 就地展开）。后端是唯一真源，所以用 @State 影子状态
    // 而不是 @AppStorage —— 本地也存一份的话，换设备/运维改了后端配置，UI 就会显示假状态。
    @State var tsRouting = TypesafeRouting.fallback
    @State var tsBreaker = TypesafeBreaker.closed
    @State var tsSyncing = false   // 读回来时抑制回声 POST（同 localModelSyncing 口径）
    @State var tsBusy = false
    @State var tsError = ""
    // v2.0.88：Face ID 登录开关（关闭后删除 Keychain 凭据，登录页不再显示快捷按钮）
    @AppStorage("qingliao_faceid_login") var faceIDLogin = true
    @State var faceIDAuthFailed = false   // v2.0.89f：开关打开时系统授权失败提示
    // v2.0.92：App 锁开关（启动时 Face ID 验证）
    @AppStorage("qingliao_app_lock") var appLockOn = false
    @State var appLockAuthFailed = false
    // v2.0.128：AI 输出行高（0-6 步进 0.5，默认 1.0 = 紧凑；滑条控制）已随死代码外观块删除——
    // 行高/流光/Siri 发光全部统一由 AppearanceSheet 管理（与云端同一组件）
    // v2.0.102：切回设置页刷新计数（密码管理/记忆增删后行尾数字即时更新，原只有 .task 首刷）
    // v4.0.6：卡通宠物自定义页 + 大头像摘要所需的 key
    // （与 PetStudioSheet 共用同一组 @AppStorage，所以摘要改完立刻刷新，不需要额外通知）
    @State var showPetStudio = false
    // v4.0.22：设置页搜索（顶部搜索框 + 结果区；索引见 Core/SettingsSearchIndex.swift）
    @State var settingsQuery = ""
    /// 2026-10-07：一级页收成 6 个分组行后，搜索「滚到分组看」改为直接打开对应二级页
    /// （分组内容已搬进二级页，一级页没有滚动锚点了）
    @State var searchNavTarget: SettingsSubpage?
    @AppStorage(PetKeys.style) var petStyle: PetStyle = .liquid
    @AppStorage(PetKeys.face) var petFace: PetFace = .calm
    var body: some View {
        VStack(spacing: 0) {
            // J 线 2026-10-06：Muse 式顶栏 —— 居中小标题「设置」（约 20pt 半粗）+ 右上 X 关闭
            // （sheet 场景）。玻璃只用在 X 按钮上。
            HStack {
                Color.clear.frame(width: 44, height: 44)
                Spacer()
                Text("设置")
                    .font(.system(size: Typography.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    Haptics.tap()
                    dismissSettings()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: Typography.title, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .a11yGlass(.regular, in: Circle(), stroke: Color.primary.opacity(0.08))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, Spacing.section)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
            // 2026-10-07 Item 2：AI 形象独立大卡片（Muse 订阅卡同款）：64pt 头像 +
            // 「Nori」大标题 + petSummary 副标题 + 右箭头；点按进 AI 形象设置
            // （复用 PetStudioSheet 链路，showPetStudio 不变）。
            GraySettingsGroup(title: "AI形象") {
                Button {
                    Haptics.tap()
                    showPetStudio = true
                } label: {
                    HStack(spacing: 16) {
                        ROTAvatarView(state: .idle, size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nori")
                                .font(.system(size: Typography.titleXL, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(petSummary)
                                .font(.system(size: Typography.subhead))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: Typography.subhead, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.section)
            .padding(.top, Spacing.xs)
            // 2026-10-07 真机反馈：AI形象卡与搜索框间距偏小——卡下方加 6pt，
            // 与搜索框拉开呼吸感（仍远小于分组行 28pt 间距）
            .padding(.bottom, Spacing.sm)
            // v4.0.22：设置项越堆越多，顶部给一行搜索框（索引与匹配见 Core/SettingsSearchIndex.swift）
            SettingsSearchBar(text: $settingsQuery)
            ScrollView {
                // 2026-10-07 Item 1：一级页只剩 6 个分组行（大厂顺序：个人中心在前），
                // 各组内容整体搬进二级页（见 SettingsGroups.swift），GraySettingsGroup 原样复用
                VStack(spacing: 28) {
                    // v4.0.22：搜索结果插在最上面（逻辑不变）；下面是 6 个分组行
                    if !settingsQuery.isEmpty {
                        SettingsSearchList(query: settingsQuery) { openSearchEntry($0) }
                    }
                    GraySettingsGroup(title: "") {
                        groupLink(.profile)
                        MuseRowDivider()
                        groupLink(.ai)
                        MuseRowDivider()
                        groupLink(.connector)
                        MuseRowDivider()
                        groupLink(.general)
                        MuseRowDivider()
                        groupLink(.notify)
                        MuseRowDivider()
                        groupLink(.about)
                    }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, 100)
                // v3.4.28：横屏限宽居中
                .frame(maxWidth: .infinity)
                .frame(maxWidth: AdaptiveLayout.contentMaxWidth(hSizeSettings))
            }
            .scrollPosition($scrollPos)
        }
        // 2026-10-07：搜索 sec:xxx 直达二级页（编程式 push；分组行本身用 NavigationLink 被动跳转）
        .navigationDestination(item: $searchNavTarget) { subpage(for: $0) }
        // 灰度重做 B 路：浅灰分组底（参考图是浅色渐变；灰度语言里用 systemGroupedBackground）
        .background(Color(uiColor: .systemGroupedBackground))
        .background(settingsCold1())
        .background(settingsCold2())
        .background(settingsCold3())
        .background(settingsCold4())
        .background(settingsCold5())
        .background(settingsCold6())
        .background(settingsCold7())
        .background(settingsCold8())
    }

    /// 灰度重做 2026-10-06 晚：设置页返回（sheet 场景 dismiss；导航栈场景靠系统返回）
    private func dismissSettings() {
        dismiss()
    }

    /// 深度治理：行为型深层修饰器下沉背景层（.background 不影响布局，语义等价）
    private func settingsCold1() -> some View {
        Color.clear
        .sheet(isPresented: $showPasswordSheet) {
            PasswordSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAppearance) {
            // v3.0.4：外观弹窗（与云端共用同一组件，样式统一）
            AppearanceSheet()
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        .sheet(isPresented: $showPetStudio) {
            // v4.0.6：卡通宠物自定义（形象 / 表情 / 行为动作 / 动画档；改完聊天页联动）
            PetStudioSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHomeShortcuts) {
            // v3.9.82：桌面快捷方式选择（动态 shortcutItems，最多 4 项）
            HomeShortcutSheet()
                .presentationDetents([.medium, .large])
        }
    }

    /// 深度治理：行为型深层修饰器下沉背景层（.background 不影响布局，语义等价）
    private func settingsCold2() -> some View {
        Color.clear
        .sheet(isPresented: $showTasks) {
            TasksView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showLogs) {
            LogsView()
                .presentationDetents([.medium, .large])
        }
        // v4.0.61：弹窗关闭时清掉「搜索直达」标记。
        // ⚠️ `onDismiss` 是 `sheet(isPresented:onDismiss:content:)` 的**参数**，不是 View 修饰符 ——
        //    挂到内容视图上会报 `value of type 'some View' has no member 'onDismiss'`，
        //    本机 `-parse` 全绿、只有 Archive 抓得到（CI run #694 实踩）。
        .sheet(isPresented: $showConnSettings, onDismiss: { connOpenPinPath = false }) {
            ConnSettingsView(initiallyShowPinPath: connOpenPinPath)
                .presentationDetents([.medium, .large])
        }
        // J 线 2026-10-06：模型管理独立页已删（模型切换并入连接设置页内）
    }

    /// 深度治理：行为型深层修饰器下沉背景层（.background 不影响布局，语义等价）
    private func settingsCold3() -> some View {
        Color.clear
        // J 线 2026-10-06：微信通道模型页已删（微信走「对接第三方」platforms 统一管理）
        .sheet(isPresented: $showAbout) {
            AboutView()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSecrets) {
            SecretsView()
                .presentationDetents([.medium, .large])
        }
        // v2.0.81：知识库
        .sheet(isPresented: $showKB) {
            KBView()
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // 2026-10-07：技能管理
        .sheet(isPresented: $showSkills) {
            SkillsView()
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // v2.0.87：AI 记忆
    }

    /// 深度治理：行为型深层修饰器下沉背景层（.background 不影响布局，语义等价）
    private func settingsCold4() -> some View {
        Color.clear
        .sheet(isPresented: $showMemory) {
            MemoryView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHASettings) {
            HASettingsSheet()
                .presentationDetents([.medium])
        }
        // v3.5.0：MCP 工具服务管理
        .sheet(isPresented: $showMCPSettings) {
            MCPSettingsSheet()
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // v4.0.x：邮件接入
        .sheet(isPresented: $showMailSettings) {
            MailSettingsSheet()
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // v4.0.x：网盘接入
    }

    /// 深度治理：行为型深层修饰器下沉背景层（.background 不影响布局，语义等价）
    private func settingsCold5() -> some View {
        Color.clear
        .sheet(isPresented: $showCloudDrive) {
            CloudDriveSettingsSheet()
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // v3.9.95：权限与 AI 操控已拆散 —— 本机权限逐项进「连接应用」页（AppPermissionKit 逐项授权）
        .sheet(isPresented: $showConnectApps) {
            ConnectAppsView()
        }
        // v3.5.x：生活卡片设置页（股票 / 资讯 / 快递）
        .sheet(isPresented: $showLifeCards) {
            LifeCardsSettingsView()
                .presentationDetents([.medium, .large])
        }
        // v3.9.32：定时提醒（纯本地 UNCalendarNotificationTrigger，无后端依赖）
        .sheet(isPresented: $showQuickReminder) {
            QuickReminderSheet()
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // v3.9.32：文件管理（上传目录浏览：预览 / 分享 / 重命名 / 删除）
    }

    /// 深度治理：行为型深层修饰器下沉背景层（.background 不影响布局，语义等价）
    private func settingsCold6() -> some View {
        Color.clear
        .sheet(isPresented: $showFilesManager) {
            FilesManagerSheet()
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // v4.0.11：主动 Agent（后端 proactive_agent 的唯一 UI 面）
        .sheet(isPresented: $showProactive) {
            ProactiveAgentSheet()
                // v4.0.x：原为 [.large]（锁死全屏），与全站半屏弹窗不一致 → 统一为 [.medium, .large]
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // v2.0.105：Agent 关键词管理
        .sheet(isPresented: $showAgentKeywords) {
            AgentKeywordsSheet()
                .scrollContentBackground(.hidden)
        }
        // v2.0.113：Agent 记忆弹窗（同 AI 记忆样式）
        .sheet(isPresented: $showAgentMemory) {
            AgentMemorySheet()
                .scrollContentBackground(.hidden)
        }
        // J 线 2026-10-06：Agent 模型独立页已删（主模型在「连接设置」统一管理）
        // J 线 2026-10-06：对接第三方（消息渠道平台列表，OAuth 点按授权）
        .sheet(isPresented: $showThirdParty) {
            ThirdPartyView()
                .presentationDetents([.medium, .large])
        }
        // J 线 2026-10-06：朗读声音（TTS 音色设置）
        .sheet(isPresented: $showReadAloud) {
            ReadAloudSheet()
                .presentationDetents([.medium, .large])
        }
    }

    /// 深度治理：行为型深层修饰器下沉背景层（.background 不影响布局，语义等价）
    private func settingsCold7() -> some View {
        Color.clear
        // J 线 2026-10-06：Agent 模型独立页已删（见 settingsCold6 注释）
        // v2.0.116：执行历史弹窗（v3.9.35：补 presentationDetents——漏挂导致默认全屏，
        // 与全站弹窗「默认半屏 medium、可上拉 large」不一致）
        .sheet(isPresented: $showHistory) {
            HistorySheet()
                .presentationDetents([.medium, .large])
        }
        // v3.6.0：原「崩溃日志」行整合为「诊断」页（App 自身诊断：版本/设备/网络/后端连通性/
        // 崩溃与卡顿记录/一键复制导出/手动上报），崩溃日志查看导出在该页内，入口不再重复。
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
                .presentationDetents([.medium, .large])
        }
        // K 线 2026-10-06：本地模型管理弹窗已删。
        // K 线 2026-10-06：智能路由/上下文压缩/使用说明二级页（行内展开收进二级页）
        .sheet(isPresented: $showRoutingSettings) {
            routingSettingsPage
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        .sheet(isPresented: $showContextCompress) {
            contextCompressPage
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        .sheet(isPresented: $showAgentHelp) {
            agentHelpPage
                .presentationDetents([.medium, .large])
                .scrollContentBackground(.hidden)
        }
        // v3.9.26：能力示例（5 种卡片形态展示，零后端、纯 App 内样例数据）
        // v3.9.27：补 .scrollContentBackground(.hidden)——ScrollView 自带底会盖住系统玻璃弹窗底
        //（与 v3.9.23「清遮挡层、不覆盖材质」定稿同规则，用户报的「能力示例弹窗圆角背景不对」即此）
    }

    /// 深度治理：行为型深层修饰器下沉背景层（.background 不影响布局，语义等价）
    private func settingsCold8() -> some View {
        Color.clear
        // J 线 2026-10-06：能力示例（卡片画廊）整行删掉，不再挂载
        // v2.0.102：切回设置页刷新计数（密码管理/记忆增删后行尾数字即时更新，原只有 .task 首刷）
        .onAppear { Task { await loadCounts() } }
        .task {
            await loadCounts()
            await loadTypesafeRouting()   // v3.9.56：进设置页即读后端真实路由开关/熔断状态
        }
    }

    // MARK: - v4.0.22 设置页搜索

    /// 搜索结果点开：弹窗类直接开对应弹窗；原来「滚到所属分组看」的 sec:xxx 现在直开对应二级页
    /// （2026-10-07：一级页只剩 6 个分组行，内容全搬进二级页，滚动锚点已删除）。
    /// 这些 route 字面量与 Core/SettingsSearchIndex.swift 的 entries 一一对应 ——
    /// 真值表反向核验「索引里每条 route 都在这里被处理」，漏一条就是「搜到了、点下去没反应」。
    private func openSearchEntry(_ entry: SettingsSearchEntry) {
        settingsQuery = ""
        switch entry.route {
        case "password": showPasswordSheet = true
        case "conn":
            connOpenPinPath = false
            showConnSettings = true
        // J 线 2026-10-06：已删 route 的映射（Core/SettingsSearchIndex.swift 是禁区，映射写在这里）：
        // model→连接设置（模型切换并入该页）；wechatChannel→对接第三方；
        // appPermissions→连接应用（权限已拆散进该页）；cardGallery→忽略（整行删掉）；
        // agentModel→连接设置（Agent 模型独立页已删，一个功能一个入口）
        case "model":
            connOpenPinPath = false
            showConnSettings = true
        case "wechatChannel": showThirdParty = true
        case "ha": showHASettings = true
        case "mcp": showMCPSettings = true
        case "mail": showMailSettings = true
        case "cloudDrive": showCloudDrive = true
        case "appPermissions": showConnectApps = true
        case "kb": showKB = true
        case "memory": showMemory = true
        case "cardGallery": break
        case "secrets": showSecrets = true
        case "tasks": showTasks = true
        case "history": showHistory = true
        case "logs": showLogs = true
        case "diagnostics": showDiagnostics = true
        case "pinPath":
            // v4.0.61：钉一钉存储已搬进「连接设置」→ 打开该页并直达它的 sheet
            connOpenPinPath = true
            showConnSettings = true
        case "lifeCards": showLifeCards = true
        case "quickReminder": showQuickReminder = true
        case "filesManager": showFilesManager = true
        case "proactive": showProactive = true
        case "agentModel":
            connOpenPinPath = false
            showConnSettings = true
        case "agentHelp": showAgentHelp = true   // 弹窗直开（原行内展开已收进二级页，锚点不再存在）
        case "agentKeywords": showAgentKeywords = true
        case "agentMemory": showAgentMemory = true
        case "appearance": showAppearance = true
        case "pet": showPetStudio = true
        case "homeShortcuts": showHomeShortcuts = true
        case "about": showAbout = true
        // 2026-10-07：一级页收成 6 个分组行后，「滚到分组看」改为直开对应二级页
        // （分组内容已搬进二级页，一级页没有锚点了）
        case "sec:account": searchNavTarget = .profile
        case "sec:ai": searchNavTarget = .ai
        case "sec:appearance": searchNavTarget = .general
        default: break
        }
    }
}

// MARK: ===== 以下原为 Features/Settings/SettingsViewSections.swift =====

// MARK: - Section 计算属性（2026-10-07：一级/二级重构：6 分组改名，内容整体搬进二级页）
// 只搬行、不改功能：所有 @State 弹窗/sheet 开关与行为原样保留。
// 行 = 单色线条图标 + 标题(+副标题) + 灰 chevron；行间细分割线用 MuseRowDivider。

extension SettingsView {

    // MARK: - AI设置

    @ViewBuilder var agentSection: some View {
        GraySettingsGroup(title: "AI设置") {
            GraySettingsRow(icon: "brain.head.profile", title: "AI 记忆", value: "\(memoryCount) 条") { showMemory = true }
            MuseRowDivider()
            GraySettingsRow(icon: "list.bullet.rectangle", title: "Agent 记忆",
                            value: agentRuleCount > 0 ? "\(agentRuleCount) 条规则" : "暂无") { showAgentMemory = true }
            MuseRowDivider()
            GraySettingsRow(icon: "tag", title: "Agent 关键词", subtitle: "关键词触发规则") { showAgentKeywords = true }
            MuseRowDivider()
            GraySettingsRow(icon: "bolt", title: "主动 Agent", subtitle: "AI 主动提醒 · 额度/免打扰/每日复盘") { showProactive = true }
            MuseRowDivider()
            GraySettingsRow(icon: "timer", title: "定时任务", subtitle: "智能体按计划自动执行") { showTasks = true }
            MuseRowDivider()
            GraySettingsRow(icon: "clock.arrow.circlepath", title: "任务记录", subtitle: "自动任务的执行记录") { showHistory = true }
            MuseRowDivider()
            GraySettingsRow(icon: "book.closed", title: "知识库", subtitle: "文档检索问答") { showKB = true }
            MuseRowDivider()
            GraySettingsRow(icon: "puzzlepiece.extension", title: "技能", subtitle: "给 AI 装上领域能力") { showSkills = true }
            MuseRowDivider()
            // K 线 2026-10-06：判定参数区收进二级页（分流方式/灵敏度/等待超时），列表不再展开
            GraySettingsRow(icon: "arrow.triangle.branch", title: "智能路由",
                            subtitle: tsRouting.subtitleText,
                            value: tsRouting.enabled ? "已开启" : "已关闭") { showRoutingSettings = true }
            MuseRowDivider()
            // K 线 2026-10-06：阈值区收进二级页，列表不再展开
            GraySettingsRow(icon: "rectangle.compress.vertical", title: "上下文自动压缩",
                            subtitle: contextAutoCompress ? "已开启 · 约 \(contextThreshold) 字" : "token超限时AI摘要压缩历史消息") { showContextCompress = true }
        }
    }

    // MARK: - 连接器

    @ViewBuilder var connectionSection: some View {
        GraySettingsGroup(title: "连接器") {
            GraySettingsRow(icon: "network", title: "连接设置") { showConnSettings = true }
            MuseRowDivider()
            GraySettingsRow(icon: "square.grid.2x2", title: "连接应用",
                            subtitle: "本机权限与云端服务，点按授权") { showConnectApps = true }
            MuseRowDivider()
            // K 线 2026-10-06：本地模型整套删除（Hermes 是唯一后端）。
            GraySettingsRow(icon: "hammer", title: "工具服务", subtitle: "可接入外部工具") { showMCPSettings = true }
            MuseRowDivider()
            BackendUpdateRow()
        }
    }

    // MARK: - 通用设置

    @ViewBuilder var generalSection: some View {
        GraySettingsGroup(title: "通用设置") {
            GraySettingsRow(icon: "paintbrush", title: "外观", value: appearanceName) {
                withAnimation(Motion.snap) { showAppearance = true }
            }
            MuseRowDivider()
            GraySettingsRow(icon: "waveform", title: "朗读声音", subtitle: "AI 语音朗读的音色") { showReadAloud = true }
            MuseRowDivider()
            GraySettingsToggleRow(icon: "iphone.radiowaves.left.and.right", title: "震动反馈", isOn: $hapticsOn)
            MuseRowDivider()
            GraySettingsToggleRow(icon: "rectangle.grid.2x2", title: "首页卡片", isOn: $homeCardsOn)
            MuseRowDivider()
            GraySettingsRow(icon: "square.grid.3x3", title: "桌面快捷方式",
                            value: "已选 \(HomeShortcutStore.ids(from: homeShortcutsRaw).count)/\(HomeShortcut.maxCount)") { showHomeShortcuts = true }
            MuseRowDivider()
            GraySettingsRow(icon: "rectangle.stack", title: "生活卡片", subtitle: "股票 / 资讯 / 快递") { showLifeCards = true }
            MuseRowDivider()
            GraySettingsRow(icon: "folder", title: "文件管理", subtitle: "上传目录里的文件") { showFilesManager = true }
        }
    }

    // MARK: - 个人中心

    @ViewBuilder var accountSection: some View {
        GraySettingsGroup(title: "个人中心") {
            GraySettingsStaticRow(icon: "person.circle", title: auth.username, subtitle: "已登录")
            MuseRowDivider()
            GraySettingsRow(icon: "key", title: "修改密码") { showPasswordSheet = true }
            MuseRowDivider()
            GraySettingsToggleRow(icon: "faceid", title: "Face ID 登录", isOn: $faceIDLogin)
                .onChange(of: faceIDLogin) { _, on in
                    if on { requestFaceIDAuth() } else { FaceIDStore.clear() }
                }
                .alert("Face ID 未授权", isPresented: $faceIDAuthFailed) {
                    Button("好的", role: .cancel) {}
                } message: {
                    Text("未通过系统 Face ID 验证，登录页快捷登录不可用。")
                }
            MuseRowDivider()
            GraySettingsToggleRow(icon: "lock", title: "App 锁", isOn: $appLockOn)
                .onChange(of: appLockOn) { _, on in
                    if on { requestAppLockAuth() }
                }
                .alert("Face ID 未授权", isPresented: $appLockAuthFailed) {
                    Button("好的", role: .cancel) {}
                } message: {
                    Text("未通过系统 Face ID 验证，App 锁不可用。")
                }
            MuseRowDivider()
            GraySettingsRow(icon: "lock.rectangle.stack", title: "密码管理", value: "\(secretCount) 条密码") { showSecrets = true }
            MuseRowDivider()
            // 2026-10-07 真机反馈：退出登录从「关于我们」搬到个人中心（一个功能一个入口）
            Button {
                confirmLogout = true
            } label: {
                Text("退出登录")
                    .font(.system(size: Typography.title, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
            }
            .buttonStyle(.plain)
        }
        .confirmationDialog("退出登录？", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { auth.logout() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后回到登录页。云端配置（API Key）仍保留在手机本地。")
        }
    }

    // MARK: - 通知

    @ViewBuilder var notificationSection: some View {
        GraySettingsGroup(title: "通知") {
            GraySettingsRow(icon: "bell.badge", title: "本地提醒", subtitle: "一句话定时间 · 离线可用") { showQuickReminder = true }
        }
    }

    // MARK: - 关于我们

    @ViewBuilder var aboutSection: some View {
        GraySettingsGroup(title: "关于我们") {
            GraySettingsRow(icon: "info.circle", title: "关于Nori") { showAbout = true }
            MuseRowDivider()
            GraySettingsRow(icon: "doc.text", title: "日志") { showLogs = true }
            MuseRowDivider()
            GraySettingsRow(icon: "stethoscope", title: "诊断",
                            value: CrashReporter.hasPendingLog() ? "有待查看" : "设备/网络/崩溃记录") { showDiagnostics = true }
            MuseRowDivider()
            // K 线 2026-10-06：使用说明从智能体组移到关于组（静态帮助）
            GraySettingsRow(icon: "questionmark.circle", title: "使用说明") { showAgentHelp = true }
        }
    }

    /// v3.9.56：智能路由「就地展开」参数区。
    /// 灰度重做 B 路：去分割线，行距对标新行组件；判定/回写逻辑原样保留。
    @ViewBuilder var tsRoutingParams: some View {
        // 分流方式：两枚胶囊。没有「关闭」档 —— 关掉上面那个开关就是不判定
        HStack(spacing: 12) {
            Text("分流方式").font(.system(size: Typography.title))
            Spacer(minLength: 12)
            tsCapsule("智能分流", on: tsRouting.mode == "smart") {
                Task { await saveTypesafeRouting(["mode": "smart"]) }
            }
            tsCapsule("强制 Agent", on: tsRouting.mode == "force_agent") {
                Task { await saveTypesafeRouting(["mode": "force_agent"]) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.xl)

        // 后端被 CLI 设成 mode=off 时如实说明（App 里设不出这一档，但读得到）
        if tsRouting.mode == "off" {
            tsParamNote(TypesafeRouting.modeOffHint, warn: true)
        }

        // 灵敏度：概率 ≥ 该值 → 判「要干活」。后端允许 0~1，UI 收窄到有意义的区间
        HStack(spacing: 12) {
            Text("灵敏度").font(.system(size: Typography.title))
            Spacer(minLength: 12)
            Text(tsRouting.thresholdText)
                .font(.system(size: Typography.body))
                .foregroundStyle(.secondary)
            Stepper("", value: tsThresholdBinding, in: 0.30...0.95, step: 0.05).labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.xl)

        // 等待超时：超时即回退关键词规则（不让用户等判定）
        HStack(spacing: 12) {
            Text("等待超时").font(.system(size: Typography.title))
            Spacer(minLength: 12)
            Text(tsRouting.timeoutText)
                .font(.system(size: Typography.body))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.xl)

        // 熔断状态：key 失效/上游挂掉连续失败 → 判定自动停 X 秒，期间零上游调用（不再白等）
        HStack(spacing: 8) {
            Circle()
                .fill(tsBreaker.open ? Color.red : Color.secondary.opacity(Tint.soft))
                .frame(width: 6, height: 6)
            Text(tsBreaker.statusText(tsRouting))
                .font(.system(size: Typography.subhead))
                .foregroundStyle(tsBreaker.open ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.xl)
        // 熔断期间每 5 秒跟一次后端：倒计时会走，后端半开重试成功后状态自己翻回来
        .task(id: tsBreaker.open) {
            guard tsBreaker.open else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { break }
                await loadTypesafeRouting()
                if !tsBreaker.open { break }
            }
        }

        HStack(spacing: 12) {
            tsCapsule("立即复位熔断", on: false) {
                Task { await saveTypesafeRouting(["reset_breaker": true]) }
            }
            if tsBusy { ProgressView().controlSize(.small) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, Spacing.xl)

        if !tsError.isEmpty {
            tsParamNote(tsError, warn: true)
        }
        tsParamNote(TypesafeRouting.footerText, warn: false)
    }

    /// v3.9.56：参数区小字说明（warn = 红字，否则 tertiary 灰字）
    @ViewBuilder func tsParamNote(_ text: String, warn: Bool) -> some View {
        HStack {
            Text(text)
                .font(.system(size: Typography.subhead))
                .foregroundStyle(warn ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tertiary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - K 线二级页：智能路由 / 上下文压缩 / 使用说明

    /// 智能路由二级页（K 线：判定参数区从列表行内展开收进此页）
    @ViewBuilder var routingSettingsPage: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: tsEnabledBinding) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("智能路由").font(.system(size: Typography.title))
                            Text("自动判断是否需要 AI 干活")
                                .font(.system(size: Typography.subhead)).foregroundStyle(.tertiary)
                        }
                    }
                }
                if tsRouting.enabled {
                    Section {
                        tsRoutingParams
                    }
                }
            }
            .navigationTitle("智能路由")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// 上下文自动压缩二级页（K 线：阈值区从列表行内展开收进此页）
    @ViewBuilder var contextCompressPage: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $contextAutoCompress) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("上下文自动压缩").font(.system(size: Typography.title))
                            Text("token超限时AI摘要压缩历史消息")
                                .font(.system(size: Typography.subhead)).foregroundStyle(.tertiary)
                        }
                    }
                    .onChange(of: contextAutoCompress) { _, new in
                        UserDefaults.standard.set(new, forKey: "qingliao_context_auto_compress")
                    }
                }
                if contextAutoCompress {
                    Section {
                        HStack {
                            Text("压缩阈值").font(.system(size: Typography.title))
                            Spacer()
                            Text("\(contextThreshold) 字")
                                .font(.system(size: Typography.body)).foregroundStyle(.secondary)
                            Stepper("", value: $contextThreshold, in: 1000...16000, step: 500)
                                .labelsHidden()
                        }
                        .onChange(of: contextThreshold) { _, new in
                            UserDefaults.standard.set(new, forKey: "qingliao_context_threshold")
                        }
                    } footer: {
                        Text("历史消息超过该字数时，自动用 AI 摘要压缩后再发送。")
                    }
                }
            }
            .navigationTitle("上下文自动压缩")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// 使用说明二级页（K 线：从智能体组移到关于组，行内展开改为二级页）
    @ViewBuilder var agentHelpPage: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Agent 回复恒走 Hermes 智能体：查磁盘/内存、控制设备等自动调用工具")
                        Text("▸ 直接问：查磁盘/内存/温度、控制设备、执行场景，自动调用工具回复")
                        Text("▸ 记忆规则：说「以后XX都用agent」，下次同类问题直接 Agent 处理")
                        Text("▸ 复杂任务（联网搜索/写脚本/操作文件）自动转交 Hermes 执行")
                        Text("▸ 普通聊天走 Hermes（带 AI 记忆）；Agent 只参考Nori记忆与规则")
                    }
                    .font(.system(size: Typography.body))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.sm)
                }
            }
            .navigationTitle("使用说明")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// 行尾摘要：形象 + 表情 + 动作数（一行说完，别让人点进去才发现是空的）
    private var petSummary: String {
        let on = PetKeys.enabledQuirks().count
        return "\(petStyle.name) · \(petFace.name)脸 · 动作 \(on)/\(Quirk.pool.count)"
    }
}

// MARK: - 辅助函数

extension SettingsView {

    /// v2.0.102：加载凭据/记忆计数（设置页行尾显示）
    func loadCounts() async {
        if let j = try? await auth.json("/api/secrets") {
            secretCount = (j["secrets"] as? [Any])?.count ?? 0
        }
        if let j = try? await auth.json("/api/memory/list") {
            memoryCount = (j["entries"] as? [String] ?? []).count
        }
        // J 线 2026-10-06：微信推送开关已删（不再同步 /api/push/settings）
        // v2.0.113：Agent 记忆条数（行尾数字）
        if let j = try? await auth.json("/api/agent/rules") {
            agentRuleCount = (j["rules"] as? [Any] ?? []).count
        }
    }

    var appearanceName: String {
        switch appearance {
        case "light": return "浅色"
        case "system": return "跟随系统"
        default: return "深色"
        }
    }

    // J 线 2026-10-06：模型管理独立页已删（模型切换并入「连接设置」页内模型下拉）；
    // 微信通道模型页已删（微信走「对接第三方」platforms 统一管理）。
    /// v2.0.89f：打开 Face ID 开关时立即申请系统权限（用户实测"点开关没有权限申请"）
    func requestFaceIDAuth() {
        let context = LAContext()
        var err: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            faceIDLogin = false   // 设备不支持/已被拒绝 → 回滚开关
            faceIDAuthFailed = true
            return
        }
        context.localizedReason = "用于登录页一键登录Nori"
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "用于登录页一键登录Nori") { success, error in
            DispatchQueue.main.async {
                if success { return }
                // v2.0.102：用户主动取消（userCancel）不算失败——保留开关不弹提示
                if let la = error as? LAError, la.code == .userCancel { return }
                // 拒绝/系统错误 → 回滚开关，提示去系统设置开启
                faceIDLogin = false
                faceIDAuthFailed = true
            }
        }
    }

    /// v2.0.92：打开 App 锁开关时申请权限（逻辑同 Face ID 登录）
    func requestAppLockAuth() {
        let context = LAContext()
        var err: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            appLockOn = false
            appLockAuthFailed = true
            return
        }
        context.localizedReason = "用于启动时解锁Nori"
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "用于启动时解锁Nori") { success, error in
            DispatchQueue.main.async {
                if success { return }
                // v2.0.102：用户主动取消不算失败——保留开关不弹提示
                if let la = error as? LAError, la.code == .userCancel { return }
                appLockOn = false
                appLockAuthFailed = true
            }
        }
    }
}

// MARK: - v3.9.56 TypeSafe 智能路由（读回来显示 + 改完回写；后端是唯一真源）

extension SettingsView {

    /// 开关绑定。set 里先动 UI（开关手感不等网络），POST 失败再拉回后端现状
    /// —— 防「开关显示 ON 但后端其实没开」这种脱钩（同 localModelToggle 的处置）。
    var tsEnabledBinding: Binding<Bool> {
        Binding(
            get: { tsRouting.enabled },
            set: { new in
                tsRouting.enabled = new
                guard !tsSyncing else { return }   // 读回来造成的写入不回写（否则回声 POST 循环）
                Task { await saveTypesafeRouting(["enabled": new]) }
            }
        )
    }

    /// 阈值绑定（每步一次 POST；后端改配置免重启，即时生效）
    var tsThresholdBinding: Binding<Double> {
        Binding(
            get: { tsRouting.threshold },
            set: { new in
                tsRouting.threshold = new
                guard !tsSyncing else { return }
                Task { await saveTypesafeRouting(["threshold": new]) }
            }
        )
    }

    /// 读后端真实状态（进设置页 / 熔断轮询 / 保存失败回滚，都走这一处）
    func loadTypesafeRouting() async {
        guard let j = try? await auth.json("/api/agent/typesafe/routing") else {
            tsError = "状态获取失败，请检查连接后重进本页"
            return
        }
        applyTypesafeRouting(j)
    }

    /// 把后端响应整体写进影子状态；解析失败的那一段保留上一次的值（不拿兜底值冒充后端现状）
    func applyTypesafeRouting(_ j: [String: Any]) {
        tsSyncing = true
        if let raw = j["routing"] as? [String: Any], let cfg = TypesafeRouting(json: raw) {
            tsRouting = cfg
        }
        if let raw = j["breaker"] as? [String: Any] {
            tsBreaker = TypesafeBreaker(json: raw) ?? .closed
        }
        tsSyncing = false
        tsError = ""
    }

    /// 回写（部分字段补丁）：成功以响应为准刷新；失败拉回后端现状 + 红字，绝不留下假状态。
    func saveTypesafeRouting(_ patch: [String: Any]) async {
        guard !tsBusy else { return }
        tsBusy = true
        defer { tsBusy = false }
        do {
            let j = try await auth.json("/api/agent/typesafe/routing", method: "POST", body: patch)
            if (j["ok"] as? Bool) == false {
                tsError = (j["error"] as? String) ?? "保存失败"
                await loadTypesafeRouting()
            } else {
                applyTypesafeRouting(j)
            }
        } catch {
            tsError = "保存失败，请检查连接"
            await loadTypesafeRouting()
        }
    }

    /// 参数区小胶囊。选中 = 主题色淡底 + 同色文字 + 0.8pt 同色细描边；未选中 = 中性淡底
    /// —— 走 v3.9.35「三件套」口径，不用实色胶囊（用户明确否决过实色）。
    func tsCapsule(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Typography.subhead, weight: .semibold))
                .foregroundStyle(on ? Color.accentColor : Color.primary)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .background(on ? Color.accentColor.opacity(Tint.subtle) : Color.primary.opacity(Tint.faint),
                            in: Capsule())
                .overlay(Capsule().strokeBorder(on ? Color.accentColor.opacity(0.28)
                                                   : Color.secondary.opacity(0.22),
                                                lineWidth: 0.8))
        }
        .buttonStyle(PressStyle())
    }
}
