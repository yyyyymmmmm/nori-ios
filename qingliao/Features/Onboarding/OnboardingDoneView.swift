// MARK: - 引导 ⑥ 进入对话
//
// "一切就绪" + Nori 第一条打招呼（基于初见卡片个性化）。
// "开始聊天" → RootView 收尾进主界面。
// TODO: 把这条打招呼真正注入 ChatStore 首条消息（需确认新会话创建时机，
// 目前仅做视觉预览，避免在引导里提前建会话污染会话列表）。

import SwiftUI

struct OnboardingDoneView: View {
    let nickname: String
    let need: String
    var onDone: () -> Void = {}

    /// 打招呼文案：有昵称就用昵称，有需求就点一下需求
    private var greeting: String {
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let want = need.trimmingCharacters(in: .whitespacesAndNewlines)
        let call = name.isEmpty ? "嗨，我是 Nori" : "嗨\(name)，我是 Nori"
        if want.isEmpty {
            return "\(call)。我已经准备好了，有什么想让我做的，直接跟我说。"
        } else {
            return "\(call)。我已经记住「\(want)」了。有什么想让我做的，直接跟我说。"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 完成态：黑圆盘 + 白对勾
            ZStack {
                Circle()
                    .fill(Color(uiColor: .label))
                    .frame(width: 84, height: 84)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

            Text("一切就绪")
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 18)

            // Nori 第一条消息预览
            HStack(alignment: .top, spacing: 10) {
                Image("AboutLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                Text(greeting)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color(uiColor: .darkGray))
                    .lineSpacing(4)
                    .padding(12)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4, bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16, topTrailingRadius: 16,
                            style: .continuous
                        )
                    )
                Spacer(minLength: 40)
            }
            .padding(.top, 26)

            Spacer()

            OnboardingPrimaryButton(title: "开始聊天", action: onDone)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
    }
}
