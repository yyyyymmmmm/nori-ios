// MARK: - 引导 ⑤ 初见卡片
//
// Nori 的"第一印象"：只用用户亲口给的（昵称/需求）+ 已授权权限能读到的
// 一点事实（如本周日程数）。拿不到就不写，不硬编。
// "记下来" → 存记忆（MemoStore）+ 落盘；"改一改" → TODO：进对话逐条确认。

import SwiftUI
import EventKit

struct OnboardingFirstImpressionView: View {
    let nickname: String
    let need: String
    let grantedPermissions: Set<AppCapability>
    var onDone: () -> Void = {}

    @State private var items: [String] = []
    @State private var loaded = false

    private var dateTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return "初见 · \(f.string(from: Date()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTitleBlock(
                title: "Nori 对你的\n第一印象",
                subtitle: "基于你刚告诉我的 + 已开启的能力。对不上就改一改。"
            )
            .padding(.top, 18)

            // 卡片
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image("AboutLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateTitle)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("我会记住这些，越用越懂你")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 6)

                if !loaded {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("—")
                                .foregroundStyle(.tertiary)
                            Text(item)
                                .font(.system(size: 13.5))
                                .foregroundStyle(Color(uiColor: .darkGray))
                                .lineSpacing(3)
                            Spacer()
                        }
                        .padding(.vertical, 9)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color(uiColor: .systemGray6))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.top, 22)

            Spacer()

            HStack(spacing: 10) {
                // TODO: "改一改" → 进对话让 Nori 逐条跟用户确认（需 ChatStore 注入首条确认消息）
                // 目前与"记下来"同效果：先落盘，保证流程不卡死
                Button("改一改") { saveAndDone() }
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button("记下来") { saveAndDone() }
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .label))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .task { await buildItems() }
    }

    // MARK: - 组装第一印象

    private func buildItems() async {
        var list: [String] = []
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let want = need.trimmingCharacters(in: .whitespacesAndNewlines)

        if !name.isEmpty {
            list.append("你希望我叫你「\(name)」")
        }
        if !want.isEmpty {
            list.append("你最想让我做的事：\(want)")
        }
        // 日历已授权 → 读本周日程数（只计数，不读标题，克制）
        if grantedPermissions.contains(.calendar),
           await AppPermissionKit.status(of: .calendar) == .granted,
           let count = weekEventCount(), count > 0 {
            list.append("你这周有 \(count) 个日程")
        }
        // 健康已授权 → 只记"已连接"，不编造具体数据
        if grantedPermissions.contains(.health),
           await AppPermissionKit.status(of: .health) == .granted {
            list.append("健康数据已连接，我会结合它给你建议")
        }

        items = list
        loaded = true
    }

    /// 本周日程数（周一起算）。本地数据库查询，量小，直接同步调。
    private func weekEventCount() -> Int? {
        let store = EKEventStore()
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 周一
        guard let week = cal.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let pred = store.predicateForEvents(withStart: week.start, end: week.end, calendars: nil)
        return store.events(matching: pred).count
    }

    // MARK: - 落盘

    private func saveAndDone() {
        // 昵称/需求已由 Flow 容器在 finish() 落盘；这里把第一印象写进记忆
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let want = need.trimmingCharacters(in: .whitespacesAndNewlines)
        var bits: [String] = []
        if !name.isEmpty { bits.append("用户昵称：\(name)") }
        if !want.isEmpty { bits.append("用户最想让我做的事：\(want)") }
        if !items.isEmpty { bits.append("初见印象：" + items.joined(separator: "；")) }
        if !bits.isEmpty {
            MemoStore.shared.add(content: bits.joined(separator: "\n"), source: "onboarding")
        }
        onDone()
    }
}
