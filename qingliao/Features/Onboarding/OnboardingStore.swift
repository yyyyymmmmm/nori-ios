// MARK: - 首次启动引导：状态存储
//
// 引导完成标记 / 昵称 / 一句话需求，全部落 UserDefaults。
// 老用户（已存过服务器地址）默认视为已完成，不打扰。

import Foundation

enum OnboardingStore {
    private static let completedKey = "qingliao_onboarding_completed"
    private static let nicknameKey = "qingliao_nickname"
    private static let needKey = "qingliao_onboarding_need"

    /// 是否已走完引导。老用户（此前已登录过，存过服务器地址）直接视为已完成。
    static var hasCompleted: Bool {
        get {
            if UserDefaults.standard.bool(forKey: completedKey) { return true }
            // 兼容老用户：没走过新引导但用过 App 的，不弹引导
            if UserDefaults.standard.string(forKey: "qingliao_server") != nil { return true }
            return false
        }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    /// 用户昵称（引导第③步填写，设置页可改）
    static var nickname: String {
        get { UserDefaults.standard.string(forKey: nicknameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nicknameKey) }
    }

    /// 用户一句话需求（引导第③步填写）
    static var need: String {
        get { UserDefaults.standard.string(forKey: needKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: needKey) }
    }
}

// MARK: - 引导步骤

/// 引导 6 屏：欢迎 → 连服务器 → 认识你 → 开权限 → 初见卡片 → 完成
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case server
    case profile
    case permissions
    case impression
    case done

    /// 顶部进度条：欢迎页不显示，其余 5 步显示 5 格
    var progressIndex: Int? {
        switch self {
        case .welcome: return nil
        case .server: return 0
        case .profile: return 1
        case .permissions: return 2
        case .impression: return 3
        case .done: return 4
        }
    }
}
