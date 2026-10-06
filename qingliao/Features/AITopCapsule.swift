import SwiftUI

// MARK: - F线 2026-10-06：AI 形象胶囊（Muse 式，五页顶栏统一）
//
// 顶部居中：PetAvatar（56pt，动画跟任务状态走）+ 下方压着"轻聊"名字胶囊 + 状态小字。
// 状态：连接异常 / 正在执行任务 / 正在思考… / 在线（D路 aiStatusStrip 的文案口径）。
// 点击 → 发 .qingliaoOpenTaskCenter 通知（ChatView 既有链路弹任务中心，不新造状态）。
//
// 轮询收进 AITopCapsuleState 单例：胶囊挂在 5 页，单例保证 20s 只打一次后端，
// 不随挂载页数翻倍。

/// AI 胶囊的共享状态（单例）：后台任务标题 + 服务器连通性，20s 轻量轮询一次。
@Observable @MainActor
final class AITopCapsuleState {
    static let shared = AITopCapsuleState()

    var online: Bool?
    var taskTitle: String?
    private var loopStarted = false

    /// 幂等：第一个挂载的胶囊启动轮询，后面的直接复用。
    func ensurePolling(auth: AuthStore) {
        guard !loopStarted else { return }
        loopStarted = true
        Task { await pollLoop(auth: auth) }
    }

    private func pollLoop(auth: AuthStore) async {
        // 首屏先读缓存，不闪"检测中"
        if let cached = UserDefaults.standard.object(forKey: "qingliao_server_online_cache") as? Bool {
            online = cached
        }
        while !Task.isCancelled {
            if auth.isLoggedIn, !auth.token.isEmpty {
                async let conn = auth.testConnection(server: auth.serverURL)
                async let tasks = auth.fetchActiveTasks()
                let ok = await conn.hasPrefix("✅")
                let list = await tasks
                online = ok
                UserDefaults.standard.set(ok, forKey: "qingliao_server_online_cache")
                taskTitle = list.filter { $0.status == "running" }
                    .sorted { $0.createdAt > $1.createdAt }.first?.title
            } else {
                online = nil
                taskTitle = nil
            }
            try? await Task.sleep(for: .seconds(20))
        }
    }
}

struct AITopCapsule: View {
    @Environment(AuthStore.self) private var auth
    @Environment(StreamClient.self) private var stream
    @State private var capsuleState = AITopCapsuleState.shared

    /// 状态小字：连接异常 > 正在执行任务 > 正在思考… > 在线（D路文案口径）
    private var statusText: String {
        if capsuleState.online == false { return "连接异常" }
        if capsuleState.taskTitle != nil { return "正在执行任务" }
        if stream.isStreaming { return "正在思考…" }
        return "在线"
    }

    /// 宠物态：复用 PetAvatar 的 thinking 动画；任务执行中也用 thinking 态
    private var petState: PetState {
        if capsuleState.online == false { return .alert }
        if capsuleState.taskTitle != nil || stream.isStreaming { return .thinking }
        return .idle
    }

    var body: some View {
        Button {
            Haptics.tap()
            NotificationCenter.default.post(name: .qingliaoOpenTaskCenter, object: nil)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottom) {
                    // 64pt 槽位给走动位移留余量；形象本身按 56pt 直接画
                    // （PetAvatar 警告：不许大尺寸画 + 小 frame 显示，会溢出压住别的元素）
                    PetAvatar(size: 56, state: petState, patTrigger: 0)
                        .frame(width: 64, height: 64)
                    Text("轻聊")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI 状态，打开任务中心")
        .task { capsuleState.ensurePolling(auth: auth) }
    }
}
