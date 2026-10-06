// MARK: - v4.1.0 E路 / G线返工：按住说话（Push-to-Talk，对标 Today）
//
// 交互层重写，不动转写引擎（LiveSpeechTranscriber）：
//   · 输入框右侧麦克风键（空输入时替代发送键）→ 按下即录音（DragGesture minimumDistance: 0）
//   · 录音面板：iOS 26 玻璃底 + "松手发送，上滑取消" + 30fps 实时波形
//   · 松手 → 定稿 → 非空直接发送（走 ChatView.send()）；上滑超 60pt → "松手取消"
//   · 旧 voiceMode 入口（发送键长按 / 输入框长按）已摘除，一个功能一个入口；
//     toggleVoiceMode / exitVoiceMode 函数体保留备查，不再有调用方。
//
// G线返工（2026-10-06，用户真机报"上滑取消不生效、bug 多"）：
//   ① 主根因：startPTT → liveSpeech.start() 置 isPreparing=true → ChatView 传给 ChatInputBar 的
//      transcribing 入参变 true → showMicButton 变 false → 麦克风键（手势宿主）在按住中途被换成
//      发送键 → 进行中的 DragGesture 被撕掉 → onChanged/onEnded 不再触发 → 取消失灵、状态卡死。
//      修法在 ChatInputBar：showMicButton 用 PTT 感知的 transcribingEffective。
//   ② 面板定位不再引用 GrayCapsuleTabBar（F 线正在删）→ 改走 PTTPanelAnchor 实测锚点。

import SwiftUI

extension ChatView {
    /// E路：PTT 按下。引擎启动流程与 toggleVoiceMode 起手段同源（权限/模型/代次作废）。
    func startPTT() {
        guard !pttActive else { return }
        guard !liveSpeech.isRunning, !voiceMode, !transcribing else { return }
        // 语音模型下载中：按住无效，给轻提示（不弹面板，避免"按住没反应"的死感）
        if liveSpeech.isPreparing {
            Haptics.light()
            showPTTToast("语音模型准备中…")
            return
        }
        pttBaseline = inputText
        pttPressDate = Date()
        pttCancelArmed = false
        Haptics.tap()
        inputFocus = false
        voiceStartToken += 1
        let token = voiceStartToken
        withAnimation(Motion.snap) { pttActive = true }
        Task {
            liveSpeech.onTextChange = { text in inputText = text }
            liveSpeech.onError = { message in
                // 运行期错误：收面板 + 复用既有错误弹窗口径（voiceError alert）
                pttActive = false
                inputText = pttBaseline
                voiceError = message
            }
            let started = await liveSpeech.start(baseline: pttBaseline)
            voiceDiag = liveSpeech.diagnostics
            // 准备期间用户已松手（代次变了）→ 作废本次启动，别进录音态
            guard token == voiceStartToken else {
                await liveSpeech.cancel()
                return
            }
            guard started else {
                withAnimation(Motion.snap) { pttActive = false }
                inputText = pttBaseline
                if liveSpeech.needsPermission {
                    voiceAuthFailed = true   // 复用既有授权引导 alert
                } else {
                    voiceError = liveSpeech.lastError ?? "语音识别启动失败"
                }
                return
            }
        }
    }

    /// L线：两段式语音（对标 Today）——进入 / 退出语音模式。
    /// 进入：先收键盘（TextField 暂时离场，退出时全新挂载，无 v3.9.53 重建坑）；
    /// 录音中（pttActive）不许进出，松手再说。
    func enterPTTVoiceMode() {
        guard !pttActive, !liveSpeech.isRunning else { return }
        Haptics.tap()
        inputFocus = false
        withAnimation(Motion.snap) { pttVoiceMode = true }
    }

    func exitPTTVoiceMode() {
        guard !pttActive else { return }
        withAnimation(Motion.snap) { pttVoiceMode = false }
    }

    /// E路：按住期间手指位移更新（上滑超 60pt → 取消待命，给一格刻度触感）
    func updatePTT(cancelArmed: Bool) {
        guard pttActive, pttCancelArmed != cancelArmed else { return }
        pttCancelArmed = cancelArmed
        if cancelArmed { Haptics.selection() }
    }

    /// E路：松手。cancelled = 上滑超阈值；极短按压视为误触（轻触提示）。
    func endPTT(cancelled: Bool) {
        guard pttActive else { return }
        let wasTap = Date().timeIntervalSince(pttPressDate) < 0.3
        voiceStartToken += 1   // 作废准备中的启动（与 cancelTranscribe 同口径）
        withAnimation(Motion.snap) { pttActive = false }
        pttCancelArmed = false
        if wasTap {
            // 轻触不是按住说话 → 静默取消 + 轻提示（不断 old 流程）
            Task { await liveSpeech.cancel() }
            inputText = pttBaseline
            showPTTToast("按住说话")
            return
        }
        if cancelled {
            Task { await liveSpeech.cancel() }
            inputText = pttBaseline
            Haptics.tap()
            return
        }
        transcribing = true
        Task {
            let text = await liveSpeech.stop()
            transcribing = false
            voiceDiag = liveSpeech.diagnostics
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if final.isEmpty {
                inputText = pttBaseline
                showPTTToast("没听清，请再说一次")
            } else {
                // 直接发送：走现有发送通道（与输入框点发送同一条路，不重复造逻辑）
                inputText = final
                Haptics.notify(.success)
                send()
            }
        }
    }

    /// E路：轻提示 toast（1.6s 自收，代次防抖）
    func showPTTToast(_ msg: String) {
        pttToastMessage = msg
        pttToastToken += 1
        let token = pttToastToken
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard token == pttToastToken else { return }
            withAnimation { pttToastMessage = nil }
        }
    }

    // MARK: - 录音面板 / 轻提示 overlay（不进 body 巨型链，挂在 chatBodyChrome1）

    /// E路：PTT overlay——录音面板 + 轻提示 toast
    @ViewBuilder
    var pttOverlay: some View {
        if pttActive {
            ZStack(alignment: .bottom) {
                // 底幕：只压暗，不拦截触摸（手势正按在麦克风键上，中途不能被抢）
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                PTTRecordingPanel(
                    cancelArmed: pttCancelArmed,
                    preparing: liveSpeech.isPreparing,
                    level: { liveSpeech.currentInputLevel() }
                )
                .padding(.horizontal, 16)
                // G线：面板坐输入框正上方 —— bottom padding = 输入框顶部到屏幕底部的实测距离 + 12pt 呼吸。
                // 不再引用 GrayCapsuleTabBar（F 线正在删除悬浮胶囊），不写死任何高度。
                .padding(.bottom, PTTPanelAnchor.shared.panelBottomPadding(fallback: safeAreaBottom))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        if let msg = pttToastMessage {
            VStack {
                Text(msg)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .a11yGlass(.regular, in: Capsule(), stroke: Color.primary.opacity(0.08))
                Spacer()
            }
            .padding(.top, 100)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

// MARK: - G线：录音面板锚点（替代 GrayCapsuleTabBar 高度数学）

/// G线：输入框顶部到屏幕底部的实测距离（pt），进程内单例共享。
///   · 写：ChatInputBar.body 的背景 GeometryReader（输入框 frame 变化 / 键盘升降实时更新）
///   · 读：pttOverlay（面板 bottom padding 用）
/// `@Observable` 订阅：pttOverlay 的 body 里读到 `topFromBottom` 即自动订阅，值变自动重排面板位置。
@Observable
@MainActor
final class PTTPanelAnchor {
    static let shared = PTTPanelAnchor()

    /// 输入框顶部到屏幕底部的距离。≤0 = 尚未实测。
    var topFromBottom: CGFloat = 0

    private init() {}

    /// 面板 bottom padding：实测值 + 12pt 呼吸；未实测时用兜底（安全区 + 140）。
    func panelBottomPadding(fallback safeAreaBottom: CGFloat) -> CGFloat {
        topFromBottom > 0 ? topFromBottom + 12 : safeAreaBottom + 140
    }
}

// MARK: - 录音面板（对标 Today 参考图）

/// E路：录音面板——玻璃底 + 提示文字 + 30fps 实时波形。灰度，无彩色。
struct PTTRecordingPanel: View {
    var cancelArmed: Bool
    var preparing: Bool
    var level: () -> Float

    var body: some View {
        VStack(spacing: 14) {
            if cancelArmed {
                // L线：微信式红色取消指示——上滑超 60pt 时出现，手指在此松手则取消。
                // 红色是功能性（危险/取消语义），非装饰，与灰度纪律不冲突。
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("松手取消")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red, in: Capsule())
            } else {
                Text(preparing ? "语音模型准备中…" : "松手发送，上滑取消")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            PTTWaveform(level: level)
                .frame(height: 30)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .a11yGlass(.regular,
                   in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                   stroke: Color.primary.opacity(0.08))
    }
}

/// E路：30fps 波形条——TimelineView 自驱动，不走 @State，避免整页重绘。
/// 电平经正弦抖动调制，静音时收成小圆点，有声时跳动（对标参考图的波形条）。
struct PTTWaveform: View {
    var level: () -> Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let lv = CGFloat(level())
            HStack(spacing: 4) {
                ForEach(0..<24, id: \.self) { i in
                    let wobble = 0.55 + 0.45 * sin(t * 5.0 + Double(i) * 0.65)
                    let h = 3 + lv * 26 * wobble
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.secondary)
                        .frame(width: 3, height: max(3, h))
                }
            }
        }
    }
}
