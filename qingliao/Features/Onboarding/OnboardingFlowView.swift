// MARK: - 首次启动引导：流程容器
//
// 6 屏：欢迎 → 连服务器 → 认识你 → 开权限 → 初见卡片 → 完成。
// 全程可跳过；完成状态由调用方（RootView）经 onComplete 落盘。

import SwiftUI

struct OnboardingFlowView: View {
    /// 引导走完后的回调：RootView 负责置 OnboardingStore.hasCompleted 并切主界面
    var onComplete: () -> Void = {}

    @State private var step: OnboardingStep = .welcome
    // 跨屏共享的引导数据
    @State private var nickname = ""
    @State private var need = ""
    @State private var grantedPermissions: Set<AppCapability> = []

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部细进度条（欢迎页不显示）
                if let idx = step.progressIndex {
                    OnboardingProgressBar(index: idx, total: 5)
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                }

                Group {
                    switch step {
                    case .welcome:
                        OnboardingWelcomeView(
                            onStart: { step = .server },
                            onLoginDirect: {
                                // 老用户直达登录：走完引导标记，直接进登录页
                                finish()
                            }
                        )
                    case .server:
                        OnboardingServerView(onDone: { step = .profile })
                    case .profile:
                        OnboardingProfileView(
                            nickname: $nickname,
                            need: $need,
                            onNext: { step = .permissions },
                            onSkip: { step = .permissions }
                        )
                    case .permissions:
                        OnboardingPermissionsView(
                            granted: $grantedPermissions,
                            onNext: { step = .impression },
                            onSkip: { step = .impression }
                        )
                    case .impression:
                        OnboardingFirstImpressionView(
                            nickname: nickname,
                            need: need,
                            grantedPermissions: grantedPermissions,
                            onDone: { step = .done }
                        )
                    case .done:
                        OnboardingDoneView(
                            nickname: nickname,
                            need: need,
                            onDone: { finish() }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    /// 收尾：昵称/需求落盘 → 通知 RootView
    private func finish() {
        if !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            OnboardingStore.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !need.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            OnboardingStore.need = need.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        onComplete()
    }
}

// MARK: - 顶部细进度条（5 格，黑=已走）

private struct OnboardingProgressBar: View {
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= index ? Color(uiColor: .label) : Color(uiColor: .systemGray5))
                    .frame(height: 4)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - 通用主按钮（黑底白字，iOS 26 圆角）

struct OnboardingPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(enabled ? Color(uiColor: .label) : Color(uiColor: .systemGray4))
                )
        }
        .disabled(!enabled)
    }
}

// MARK: - 通用标题区

struct OnboardingTitleBlock: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
                .lineSpacing(4)
            Text(subtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
