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
    @ObservedObject private var speech = PetSpeechDrive.shared

    /// 状态小字：连接异常 > 正在执行任务 > 正在思考… > 在线（D路文案口径）
    private var statusText: String {
        if capsuleState.online == false { return "连接异常" }
        if capsuleState.taskTitle != nil { return "正在执行任务" }
        if stream.isStreaming { return "正在思考…" }
        return "在线"
    }

    /// L线：动态猫头像状态（ROTAvatarView）——朗读中 > 任务/思考中 > 在线/异常
    private var avatarState: ROTAvatarState {
        if speech.isSpeaking { return .speaking }
        if capsuleState.taskTitle != nil || stream.isStreaming { return .thinking }
        return .idle
    }

    var body: some View {
        Button {
            Haptics.tap()
            NotificationCenter.default.post(name: .qingliaoOpenTaskCenter, object: nil)
        } label: {
            // L线：三行不重叠——56pt 头像 → 4pt 间距 → 名字胶囊 → 状态小字
            // （之前 ZStack bottom 对齐把名字压在头像下半截，真机截图实锤重叠）
            VStack(spacing: 4) {
                ROTAvatarView(state: avatarState, size: 56)
                Text("Nori")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
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
