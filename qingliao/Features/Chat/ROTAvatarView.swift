import SwiftUI

// MARK: - L线 2026-10-06：动态猫头像（ROT）
//
// 底图：qingliao/Assets.xcassets/ROTAvatar.imageset/rot_avatar.png
//   （1254×1254 透明底，全身猫；头像只取头部方形裁切，circle clip）。
// 程序化动画（对标 Muse 待机小头像的第一层：预置动画 + 状态机，不跑 AI 生成）：
//   · 呼吸：整体 2~3% 缩放正弦循环（3.2s）
//   · 眨眼：两组错开周期（4.3s / 6.1s+1.7s 偏移）制造不规律感，包络 0.18s：
//     在双眼位置盖毛色椭圆做 scaleY 1→0.06→1
//   · 状态差异：idle=呼吸+眨眼；listening=轻微前倾（放大 4% + 上移 1pt）；
//     thinking=左右微摆（±3°，4s 周期）；speaking=按 TTS 音量小幅 bounce
//     （PetSpeechDrive.shared.amount 0…1，无朗读时为 0）。
// 全部由 TimelineView(15fps) 驱动，不走高频 @State，不触发整页重绘。
// 状态由调用方（AITopCapsule）从 AITopCapsuleState + PetSpeechDrive 映射后传入。

/// 动态猫头像的状态（调用方映射后传入）
enum ROTAvatarState {
    case idle       // 在线 / 连接异常：呼吸 + 眨眼
    case listening  // 听：轻微前倾
    case thinking   // 思考中 / 执行任务：左右微摆
    case speaking   // 朗读中：按 TTS 音量 bounce
}

struct ROTAvatarView: View {
    var state: ROTAvatarState = .idle
    var size: CGFloat = 56

    @ObservedObject private var speech = PetSpeechDrive.shared
    // v4.x item7：reduceMotion 开启时渲染静止帧（t=0：呼吸中性、双眼睁开、位姿归零），不循环
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 头部方形裁切（单位坐标，经 muse.visual_grounding 核对）：
    // 脸心 ≈(0.623, 0.328)，取边长 0.59 的正方形，含耳尖 + 耳机 + 下巴。
    private let cx0: CGFloat = 0.33
    private let cy0: CGFloat = 0.03
    private let cw: CGFloat = 0.59

    // 双眼在裁切坐标系中的位置（千分制实测：左(555,352) 右(691,303) → 换算）
    private let eyes: [(x: CGFloat, y: CGFloat)] = [(0.381, 0.546), (0.612, 0.463)]
    private let eyeW: CGFloat = 0.13
    private let eyeH: CGFloat = 0.155
    // 眼周毛色（米白，按图取）
    private static let fur = Color(red: 0.957, green: 0.941, blue: 0.910)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let breathe: CGFloat = 1 + 0.025 * CGFloat(sin(t * 2 * .pi / 3.2))
            let blink = Self.blinkScale(at: t)
            let speakAmount: CGFloat = speech.isSpeaking ? CGFloat(speech.amount) : 0
            let pose = Self.pose(for: state, t: t)
            ZStack {
                croppedHead
                // 眨眼盖片：平时 scaleY=1（盖片与毛色一致，不可见），眨眼时压扁
                ForEach(0..<eyes.count, id: \.self) { i in
                    Ellipse()
                        .fill(Self.fur)
                        .frame(width: eyeW * size,
                               height: max(1.5, eyeH * size * blink))
                        .position(x: eyes[i].x * size, y: eyes[i].y * size)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(breathe + pose.scale + speakAmount * 0.035)
            .rotationEffect(.degrees(pose.rot))
            .offset(y: pose.dy - speakAmount * 1.5)
            .clipShape(Circle())
        }
        .accessibilityHidden(true)
    }

    /// 头部裁切：把 0.59×0.59 的正方形区域放大到 size×size
    private var croppedHead: some View {
        Image("ROTAvatar")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size / cw, height: size / cw)
            .offset(x: -cx0 * size / cw, y: -cy0 * size / cw)
            .frame(width: size, height: size, alignment: .topLeading)
            .clipped()
    }

    /// 眨眼包络：两组错开周期，0.18s 内 1→0.06→1；其余时间返回 1（盖片不可见）
    private static func blinkScale(at t: Double) -> CGFloat {
        for (period, phase) in [(4.3, 0.0), (6.1, 1.7)] {
            let p = (t + phase).truncatingRemainder(dividingBy: period)
            if p < 0.18 {
                return max(0.06, abs(cos(p / 0.18 * .pi)))
            }
        }
        return 1.0
    }

    /// 各状态的位姿（旋转°，y 位移 pt，附加缩放）
    private static func pose(for state: ROTAvatarState, t: Double) -> (rot: Double, dy: CGFloat, scale: CGFloat) {
        switch state {
        case .idle:
            return (0, 0, 0)
        case .listening:
            return (0, -1.0, 0.04)
        case .thinking:
            return (3.0 * sin(t * 2 * .pi / 4.0), 0, 0)
        case .speaking:
            return (0, 0, 0.01)
        }
    }
}
