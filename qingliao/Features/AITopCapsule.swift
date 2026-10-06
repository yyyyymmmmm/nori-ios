import SwiftUI

// MARK: - F线 2026-10-06：AI 形象胶囊（Muse 式，五页顶栏统一）
//
// 顶部居中：单行小胶囊——28pt 动态猫头像 + "Nori" + 状态小字，总高 ~40pt。
// 状态：连接中… / 未连接 / AI 未就绪 / 正在执行任务 / 正在思考… / 待命中
//   （2026-10-07 重做：状态必须诚实——冷启动不读缓存预设在线；"在线"改"待命中"；
//    Python 通但 Hermes 不通显示"AI 未就绪"）
// 点击 → 发 .qingliaoOpenTaskCenter 通知（ChatView 既有链路弹任务中心，不新造状态）。
// 未连接时点击 = 立刻重试检测。
//
// 轮询收进 AITopCapsuleState 单例：胶囊挂在 5 页，单例保证 20s 只打一次后端，
// 不随挂载页数翻倍。

/// AI 胶囊的共享状态（单例）：后台任务标题 + 服务器连通性，20s 轻量轮询一次。
/// 2026-10-07 真机反馈重做：状态必须诚实——
/// - 冷启动不读缓存预设"在线"：没拿到真实结果前一律"连接中…"
/// - 未登录/从未检测过不再掉进"在线"（旧逻辑 `online == false` 才判异常，nil 直接穿透）
/// - "在线"改"待命中"（"在线"有歧义，像在干活）
/// - Python 通但 Hermes 不通 → "AI 未就绪"，不撒谎说待命
enum AIConnState {
    case checking    // 连接中…
    case ready       // 待命中
    case aiNotReady  // AI 未就绪
    case offline     // 未连接
}

extension Notification.Name {
    /// 流式请求真失败（非用户手动停止）——胶囊立刻重测，不等 20s 轮询
    static let qingliaoStreamFailed = Notification.Name("qingliaoStreamFailed")
}

@Observable @MainActor
final class AITopCapsuleState {
    static let shared = AITopCapsuleState()

    var connState: AIConnState = .checking
    var taskTitle: String?
    private var loopStarted = false
    private var consecutiveFailures = 0
    private weak var lastAuth: AuthStore?
    private var checkTask: Task<Void, Never>?
    private var streamFailedObserver: NSObjectProtocol?

    /// 幂等：第一个挂载的胶囊启动轮询，后面的直接复用。
    func ensurePolling(auth: AuthStore) {
        guard !loopStarted else { return }
        loopStarted = true
        lastAuth = auth
        streamFailedObserver = NotificationCenter.default.addObserver(
            forName: .qingliaoStreamFailed, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, let auth = self.lastAuth else { return }
            Task { await self.checkNow(auth: auth) }
        }
        Task { await checkNow(auth: auth) }  // 启动立刻测一次，不等 20s
        Task { await pollLoop(auth: auth) }
    }

    /// 立刻测一次：回前台 / 流失败 / 用户点"未连接"重试
    func checkNow(auth: AuthStore) async {
        checkTask?.cancel()
        let t = Task { await runCheck(auth: auth) }
        checkTask = t
        await t.value
    }

    private func pollLoop(auth: AuthStore) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(20))
            if Task.isCancelled { break }
            await runCheck(auth: auth)
        }
    }

    private func runCheck(auth: AuthStore) async {
        guard !Task.isCancelled else { return }
        guard auth.isLoggedIn, !auth.token.isEmpty else {
            connState = .checking
            taskTitle = nil
            consecutiveFailures = 0
            return
        }
        var s = auth.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.hasPrefix("http") { s = "https://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        guard !s.isEmpty else { connState = .offline; return }

        // 1) Python 后端活着吗（4s 超时；401 也算活着——鉴权问题走会话过期通道）
        let pyOK = await ping(urlString: s + "/api/auth/status", token: nil)
        guard pyOK else {
            consecutiveFailures += 1
            if consecutiveFailures >= 2 { connState = .offline }  // 防抖：连跪 2 次才判
            return
        }
        // 2) Hermes 引擎就绪吗（复用 /api/hermes/models 的 error 字段；服务端 60s 缓存，不打爆上游）
        let hermesOK = await hermesReady(urlString: s + "/api/hermes/models", token: auth.token)
        consecutiveFailures = 0
        connState = hermesOK ? .ready : .aiNotReady

        // 后台任务标题（原有逻辑保留）
        let list = await auth.fetchActiveTasks()
        taskTitle = list.filter { $0.status == "running" }
            .sorted { $0.createdAt > $1.createdAt }.first?.title
    }

    /// 轻量存活探测：2xx/401 都算"通"，只有超时/建连失败算不通
    private func ping(urlString: String, token: String?) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var req = URLRequest(url: url, timeoutInterval: 4)
        req.httpMethod = "GET"
        if let token, !token.isEmpty { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            return (200..<500).contains(code)
        } catch {
            return false
        }
    }

    /// Hermes 心跳：200 且 error 字段为空才算就绪
    private func hermesReady(urlString: String, token: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var req = URLRequest(url: url, timeoutInterval: 4)
        req.httpMethod = "GET"
        req.setValue(token, forHTTPHeaderField: "X-Auth-Token")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 { return true }  // 鉴权问题走会话过期通道，不冤枉 Hermes
            guard code == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            let err = (json["error"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return err.isEmpty
        } catch {
            return false
        }
    }
}

struct AITopCapsule: View {
    @Environment(AuthStore.self) private var auth
    @Environment(StreamClient.self) private var stream
    @Environment(\.scenePhase) private var scenePhase
    @State private var capsuleState = AITopCapsuleState.shared
    @ObservedObject private var speech = PetSpeechDrive.shared

    /// 状态小字：连接中… > 未连接 / AI 未就绪 > 正在执行任务 > 正在思考… > 待命中
    private var statusText: String {
        switch capsuleState.connState {
        case .checking:  return "连接中…"
        case .offline:   return "未连接"
        case .aiNotReady: return "AI 未就绪"
        case .ready:
            if capsuleState.taskTitle != nil { return "正在执行任务" }
            if stream.isStreaming { return "正在思考…" }
            return "待命中"
        }
    }

    /// L线：动态猫头像状态（ROTAvatarView）——朗读中 > 任务/思考中 > 待命/连接中/异常
    private var avatarState: ROTAvatarState {
        if speech.isSpeaking { return .speaking }
        if capsuleState.taskTitle != nil || stream.isStreaming { return .thinking }
        return .idle
    }

    var body: some View {
        Button {
            Haptics.tap()
            // 未连接时点胶囊 = 立刻重试；其它状态进任务中心（原有链路）
            if capsuleState.connState == .offline {
                Task { await capsuleState.checkNow(auth: auth) }
            } else {
                NotificationCenter.default.post(name: .qingliaoOpenTaskCenter, object: nil)
            }
        } label: {
            // v4.x item8：单行小胶囊（Muse 式）——28pt 头像 + 名字 + 状态，总高 ~40pt
            HStack(spacing: 8) {
                ROTAvatarView(state: avatarState, size: 28)
                Text("Nori")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI 状态，打开任务中心")
        .task { capsuleState.ensurePolling(auth: auth) }
        // 回前台立刻重测，不等 20s 轮询
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await capsuleState.checkNow(auth: auth) }
            }
        }
    }
}
