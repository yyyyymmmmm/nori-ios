import SwiftUI

// MARK: - 看板简化（2026-10）：只留三块——健康 Hero + 记忆 Hero + Nori 今日建议
//
// 设计规范（对标健康/记忆重做）：白卡、大圆角 28、大 padding、柔和阴影；
// 数字特大黑体；零暖色、零手画图标。

// MARK: - 健康 Hero 大卡

struct HealthHeroCard: View {
    @State private var steps: Double?
    @State private var sleepHours: Double?
    @State private var showHealth = false
    @State private var loaded = false

    var body: some View {
        Button {
            showHealth = true
        } label: {
            HStack(spacing: 14) {
                // 左：红心图标 + 摘要
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Color.red, in: Circle())
                    Text("健康")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(summaryText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 右：2x2 mini 统计
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)],
                          spacing: 8) {
                    miniStat(icon: "moon.fill", color: .blue,
                             value: sleepHours.map { String(format: "%.1f", $0) } ?? "--",
                             unit: "小时", label: "睡眠")
                    miniStat(icon: "heart.fill", color: .orange,
                             value: "--", unit: "次/分", label: "心率")
                    miniStat(icon: "waveform.path.ecg", color: .yellow,
                             value: "--", unit: "毫秒", label: "HRV")
                    miniStat(icon: "figure.walk", color: .green,
                             value: steps.map { "\(Int($0))" } ?? "--",
                             unit: "步", label: "步数")
                }
                .frame(maxWidth: .infinity)
            }
            .padding(18)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showHealth) {
            HealthBoardView()
        }
        .task {
            guard !loaded else { return }
            loaded = true
            steps = await HealthStore.shared.todaySteps()
            sleepHours = await HealthStore.shared.lastNightSleepHours()
        }
    }

    private var summaryText: String {
        if steps == nil && sleepHours == nil { return "暂无数据" }
        var parts: [String] = []
        if let s = steps { parts.append("\(Int(s)) 步") }
        if let h = sleepHours { parts.append(String(format: "睡 %.1f 小时", h)) }
        return parts.joined(separator: " · ")
    }

    private func miniStat(icon: String, color: Color, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Nori 今日建议

struct TodaySuggestionCard: View {
    @Environment(AuthStore.self) private var auth
    @State private var suggestions: [Suggestion] = []
    @State private var loading = false
    @State private var loaded = false
    @State private var isFallback = false

    struct Suggestion: Identifiable {
        let id = UUID()
        let title: String
        let reason: String
        let prompt: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                Text("Nori 今日建议")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if loading {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button {
                        Haptics.tap()
                        Task { await load(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if suggestions.isEmpty && !loading {
                Text(loaded ? "暂无建议" : "加载中…")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(suggestions.prefix(3)) { s in
                    Button {
                        Haptics.tap()
                        NotificationCenter.default.post(name: .qingliaoFillInput, object: s.prompt)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 3)
                                Text(s.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(s.reason)
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 20)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if isFallback {
                Text("AI 暂不可用，显示为通用建议")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        .task {
            guard !loaded else { return }
            loaded = true
            await load()
        }
    }

    private func load(force: Bool = false) async {
        // v4.4.x：提示词收归后端（/api/agent/suggestions），iOS 只展示
        // 每日缓存仍在 iOS 做（省流量），后端也做了缓存
        let dateKey = "nori_suggestion_date"
        let cacheKey = "nori_suggestion_cache"
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)

        if !force, UserDefaults.standard.string(forKey: dateKey) == today,
           let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([CachedSuggestion].self, from: data),
           !cached.isEmpty {
            suggestions = cached.map { Suggestion(title: $0.t, reason: $0.r, prompt: $0.p) }
            isFallback = false
            return
        }

        loading = true
        defer { loading = false }
        do {
            // 2026-10-07：健康 AI 联动 —— 把健康摘要 POST 给后端，AI 基于真实数据给建议
            var health: String?
            let steps = await HealthStore.shared.todaySteps()
            let sleep = await HealthStore.shared.lastNightSleepHours()
            if steps != nil || sleep != nil {
                var parts: [String] = []
                if let s = steps { parts.append("今日步数 \(Int(s))") }
                if let h = sleep { parts.append(String(format: "昨晚睡眠 %.1f 小时", h)) }
                health = parts.joined(separator: "，")
            }
            let (data, _): (Data, Int)
            if let h = health {
                (data, _) = try await auth.request("/api/agent/suggestions", method: "POST", body: ["health": h])
            } else {
                (data, _) = try await auth.request("/api/agent/suggestions", method: "GET")
            }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = obj["suggestions"] as? [[String: Any]] else {
                throw SuggestionError.badJSON
            }
            let list: [Suggestion] = arr.compactMap { d in
                guard let t = d["title"] as? String, !t.isEmpty,
                      let p = d["prompt"] as? String, !p.isEmpty else { return nil }
                return Suggestion(title: t, reason: d["reason"] as? String ?? "", prompt: p)
            }
            guard !list.isEmpty else { throw SuggestionError.badJSON }
            suggestions = list
            isFallback = (obj["fallback"] as? Bool) ?? false
            let cached = list.map { CachedSuggestion(t: $0.title, r: $0.reason, p: $0.prompt) }
            if let cdata = try? JSONEncoder().encode(cached) {
                UserDefaults.standard.set(cdata, forKey: cacheKey)
                UserDefaults.standard.set(today, forKey: dateKey)
            }
        } catch {
            suggestions = fallbackSuggestions()
            isFallback = true
        }
    }

    private func fallbackSuggestions() -> [Suggestion] {
        [
            Suggestion(title: "规划今天", reason: "通用建议", prompt: "帮我规划一下今天的日程"),
            Suggestion(title: "健康提醒", reason: "通用建议", prompt: "提醒我今天的健康目标"),
        ]
    }

    private struct CachedSuggestion: Codable {
        let t: String; let r: String; let p: String
    }

    private enum SuggestionError: Error { case badJSON }
}
