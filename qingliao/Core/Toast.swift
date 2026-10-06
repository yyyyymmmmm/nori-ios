import SwiftUI

// MARK: - item11：底部短暂 Toast（微信式：半透明黑底白字胶囊）
//
// 用法：
//   ToastCenter.shared.show("已保存")          // 任意处调用（主线程），约 2 秒自动消失
//   ToastCenter.shared.show("已复制")
//   ToastCenter.shared.show("网络异常，已排队等待重试")
//
// 挂载（全 App 只挂一次，挂在根视图 —— 已挂在 DockTabView 根）：
//   RootView()
//       .toastHost()
//
// 规则：
//  · 连续调用自动排队，逐条展示，不吞消息；
//  · 样式走灰度（Color.black.opacity(0.72) 胶囊 + 白字），不引入彩色；
//  · 动画用 Motion.snap（轻状态变化，不抢戏）；
//  · 只做信息提示：不带按钮/不做确认 —— 需要用户操作请用 alert 或 confirm sheet；
//  · 不拦截触摸（allowsHitTesting(false)），盖在 tab bar 上方约一指位置。

/// Toast 中心：单例 + 串行队列。调用方只调 `show(_:)`（主线程）。
///
/// 口径与仓内既有单例一致（`@Observable @MainActor` + 调用侧 `@State` 持有，
/// 见 AITopCapsuleState）：Swift 6 下跨线程读写用主线程收敛，不自己造锁。
@Observable @MainActor
final class ToastCenter {
    static let shared = ToastCenter()

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    /// 当前展示中的 Toast；nil = 闲置（队列为空且无展示）
    private(set) var current: Item?

    private var queue: [Item] = []

    private init() {}

    /// 入队一条 Toast。连续调用自动排队，逐条展示约 2 秒后消失；空字串直接丢弃。
    func show(_ message: String) {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        queue.append(Item(message: text))
        pump()
    }

    /// 串行泵：一次只展示一条；展示中再 show 只入队，等当前这条 2 秒到期后自动续播下一条。
    private func pump() {
        guard current == nil, !queue.isEmpty else { return }
        current = queue.removeFirst()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self else { return }
            self.current = nil
            self.pump()
        }
    }
}

/// Toast 挂载层：根视图调一次 `.toastHost()` 即可。
private struct ToastHostModifier: ViewModifier {
    // 口径同 AITopCapsule（`@State` 持有 `@Observable @MainActor` 单例）：读 current 即订阅刷新。
    @State private var center = ToastCenter.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let item = center.current {
                    Text(item.message)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.72), in: Capsule())
                        .padding(.horizontal, 40)
                        // 让位系统 tab bar（~83pt + 安全区），Toast 悬在内容区底部上方
                        .padding(.bottom, 96)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .id(item.id)
                }
            }
            .animation(Motion.snap, value: center.current)
    }
}

extension View {
    /// 在根视图挂载 Toast 层（全 App 一次）。配合 `ToastCenter.shared.show(_:)` 使用。
    func toastHost() -> some View {
        modifier(ToastHostModifier())
    }
}
