import SwiftUI

// MARK: - 灰度重做 2026-10-06 晚（C 路）：点子 tab = AI 推荐任务
//
// 对标 Today「任务」页：大标题「点子」+ 右上圆形 + 按钮 → 发给 AI 自由创建；
// 「为你推荐」分组 + 玻璃圆角 20 推荐卡片（图标/标题/描述/右白色圆形 +）。
// 点 + → 同一条通道 `.qingliaoTaskSend` 发给 AI（一个功能一个入口：创建走对话）。
// 用户明确：不是待办清单，是 AI 推荐任务。

/// 一条 AI 推荐任务模板（本地模板；后端有推荐接口后再接）
struct RecommendationTemplate: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let desc: String
    /// 点 + 时发给 AI 的文本
    let ask: String
}

enum RecommendationsStore {
    static let templates: [RecommendationTemplate] = [
        RecommendationTemplate(
            icon: "list.bullet.clipboard",
            title: "每日优先事项简报",
            desc: "每天早上从日程、待办和消息里整理最重要的几件事。",
            ask: "请为我生成今天的优先事项简报"
        ),
        RecommendationTemplate(
            icon: "envelope",
            title: "邮件今日速览",
            desc: "把新邮件按需要回复、需要行动、等待结果和仅供了解分类。",
            ask: "请帮我速览今天的邮件"
        ),
        RecommendationTemplate(
            icon: "envelope.open",
            title: "待回复事项检查",
            desc: "找出邮件和消息里仍需要你回复、确认或补材料的对话。",
            ask: "请检查我有哪些待回复的事项"
        ),
        RecommendationTemplate(
            icon: "calendar",
            title: "今日会议准备",
            desc: "提前整理今天重要会议的背景、议程和需要确认的问题。",
            ask: "请帮我准备今天的会议"
        ),
        RecommendationTemplate(
            icon: "chart.line.uptrend.xyaxis",
            title: "每周项目进展汇总",
            desc: "每周整理重点项目的进展、风险、阻塞和下一步。",
            ask: "请汇总本周的项目进展"
        ),
        RecommendationTemplate(
            icon: "alarm",
            title: "截止事项提前检查",
            desc: "提前发现未来两周的重要 Deadline，整理材料、依赖和风险。",
            ask: "请检查未来两周的截止事项"
        ),
    ]
}

struct IdeasTabView: View {
    /// 发给 AI 的唯一出口（DockTabView.askAI：切聊天页 + 0.35s 闸 + post）
    let onAskAI: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("点子")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Button {
                            onAskAI("请帮我创建一个新的任务")
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("让 AI 自由创建任务")
                    }
                    .padding(.top, 12)

                    Text("为你推荐")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    VStack(spacing: 12) {
                        ForEach(RecommendationsStore.templates) { t in
                            RecommendationCard(template: t) {
                                onAskAI(t.ask)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.section)
                .padding(.bottom, 100)   // 给悬浮 tab bar 留空
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// 推荐卡片：玻璃圆角 20（对标 Today 任务页）
private struct RecommendationCard: View {
    let template: RecommendationTemplate
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: template.icon)
                .font(.system(size: 22))
                .foregroundStyle(.primary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(template.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                Text(template.desc)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.white, in: Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("把「\(template.title)」发给 AI")
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
