// MARK: - 引导 ① 欢迎
//
// Nori 真实品牌图（Image("AboutLogo")，自带深色变体）+ 一句话。
// 不做多页轮播：行业共识是"登录即达、零打扰"。

import SwiftUI

struct OnboardingWelcomeView: View {
    var onStart: () -> Void = {}
    var onLoginDirect: () -> Void = {}

    var body: some View {
        VStack {
            Spacer()

            // Nori 品牌图：真实资产，勿手画
            Image("AboutLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 24, y: 12)

            Text("Nori")
                .font(.system(size: 34, weight: .heavy))
                .tracking(2)
                .padding(.top, 22)

            Text("让 AI 真正替你做事。")
                .font(.system(size: 14.5))
                .foregroundStyle(.secondary)
                .padding(.top, 10)

            Spacer()

            OnboardingPrimaryButton(title: "开始使用", action: onStart)

            Button("我已有账号，直接登录") { onLoginDirect() }
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
    }
}
