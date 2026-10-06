import SwiftUI

// MARK: - item9：微信式顶部离线条
//
// 用法（已挂在 DockTabView 根，`.safeAreaInset(edge: .top)`）：
//   RootView()
//       .safeAreaInset(edge: .top, spacing: 0) { OfflineBanner() }
//
// 为什么用 safeAreaInset 而不是 overlay：各页顶部都有 AITopCapsule（Nori 胶囊），
// overlay 顶部会直接盖住它；safeAreaInset 把安全区往下推，胶囊整体下移、不被遮挡。
//
// 为什么轮询而不是订阅：NetworkMonitor 是 unfair_lock 手工同步的普通类（非 @Observable），
// 没有发布通道；2 秒轮询一次 isSatisfied 足够（离线条不需要毫秒级响应），
// 比给 NetworkMonitor 加 @Observable 侵入小（它是 @unchecked Sendable，多线程读写的老代码）。
//
// 口径：只反映「本机网络是否可用」（NWPath satisfied），不等同于「后端连得上」——
// 后者由 AITopCapsule 的状态小字（连接异常/在线）负责，两者不互相替代。

/// 微信式顶部离线细条：离线时显示「网络不可用，请检查网络连接」，在线时高度为 0。
struct OfflineBanner: View {
    @State private var offline = false

    var body: some View {
        Group {
            if offline {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                    Text("网络不可用，请检查网络连接")
                }
                .font(.caption)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.78))   // 灰度：黑底白字，不引入彩色
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.snap, value: offline)
        .onAppear {
            offline = !NetworkMonitor.shared.isSatisfied
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            let now = !NetworkMonitor.shared.isSatisfied
            if now != offline { offline = now }
        }
    }
}
