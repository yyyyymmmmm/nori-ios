// AI形象页：Nori 形象展示（v4.4：旧程序化宠物 PetAvatar 全面替换为新猫 ROTAvatarView，
// 定制项随之退役——新形象是固定品牌形象，动画由 AI 状态驱动）

import SwiftUI

struct PetStudioSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 大头像预览（实时动态）
                Section {
                    VStack(spacing: Spacing.sm) {
                        ROTAvatarView(state: .idle, size: 120)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xs)
                        Text("Nori · 在线")
                            .font(.system(size: Typography.subhead))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // MARK: 状态演示
                Section {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)],
                              spacing: 16) {
                        stateDemo(state: .idle, label: "在线")
                        stateDemo(state: .listening, label: "聆听中")
                        stateDemo(state: .thinking, label: "思考中")
                        stateDemo(state: .speaking, label: "说话中")
                    }
                    .padding(.vertical, Spacing.xs)
                    Text("Nori 的形象会随 AI 状态自动变化：聆听时前倾，思考时微摆，说话时随语音起伏。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("状态")
                }
            }
            .navigationTitle("AI形象")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func stateDemo(state: ROTAvatarState, label: String) -> some View {
        VStack(spacing: 8) {
            ROTAvatarView(state: state, size: 72)
            Text(label)
                .font(.system(size: Typography.caption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
