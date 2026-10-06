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
    @State private var suggestions: [String] = []
    @State private var loading = false
    @State private var loaded = false

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
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if suggestions.isEmpty && !loading {
                Text(loaded ? "暂无建议" : "加载中…")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(suggestions.prefix(2), id: \.self) { s in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 3)
                        Text(s)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
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

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            // 后端智能建议接口（/api/agent/suggestion），失败静默
            let (data, _) = try await auth.request("/api/agent/suggestion", method: "GET")
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = obj["suggestions"] as? [String] {
                suggestions = list
            }
        } catch {
            // 静默失败，显示"暂无建议"
        }
    }
}
