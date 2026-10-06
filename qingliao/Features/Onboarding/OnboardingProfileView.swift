// MARK: - 引导 ③ 认识你
//
// 只问两项：昵称 + 一句话需求。右上角"跳过"永远可点，不绑架。

import SwiftUI

struct OnboardingProfileView: View {
    @Binding var nickname: String
    @Binding var need: String
    var onNext: () -> Void = {}
    var onSkip: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button("跳过") { onSkip() }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            OnboardingTitleBlock(
                title: "让 Nori\n认识你",
                subtitle: "两句话就够，以后随时能改。"
            )
            .padding(.top, 8)

            Text("希望 Nori 怎么称呼你")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 26)
            TextField("比如：阿远", text: $nickname)
                .font(.system(size: 14.5))
                .padding(14)
                .background(Color(uiColor: .systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 8)

            Text("最希望 Nori 帮你做什么（一句话）")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            TextField("比如：每天早上提醒我日程", text: $need)
                .font(.system(size: 14.5))
                .padding(14)
                .background(Color(uiColor: .systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 8)

            Spacer()

            OnboardingPrimaryButton(title: "继续", action: onNext)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
    }
}
