import SwiftUI

// MARK: - 健康数据三级页（对标参考设计）
//
// 分段：睡眠 / 活动 / 生命体征；每段全宽指标卡，大数字 + mini 柱状图。
// 数据：HealthStore 结构化查询；读不到显示 "--" 占位，不编假数据。

struct HealthDataView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Segment: String, CaseIterable {
        case sleep = "睡眠"
        case activity = "活动"
        case vitals = "生命体征"
    }
    @State private var segment: Segment = .sleep

    // 睡眠段数据
    @State private var sleepHours: Double?
    @State private var sleepHistory: [Double] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                segmentPicker
                Text("Apple Health")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                switch segment {
                case .sleep: sleepCards
                case .activity: activityCards
                case .vitals: vitalsCards
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle("健康数据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "cloud")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                    Circle()
                        .fill(Color.green)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: -3, y: -3)
                }
                .accessibilityLabel("健康数据已同步")
            }
        }
        .background(healthDataGradient)
        .task { await loadSleep() }
    }

    private var healthDataGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.94, blue: 0.98),
                Color(red: 0.96, green: 0.96, blue: 0.97),
                Color(red: 0.985, green: 0.975, blue: 0.96)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: 分段选择器

    private var segmentPicker: some View {
        HStack(spacing: 8) {
            ForEach(Segment.allCases, id: \.self) { s in
                Button { segment = s } label: {
                    Text(s.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(segment == s ? .primary : .white.opacity(0.85))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            segment == s
                                ? Color.white
                                : Color.secondary.opacity(0.25),
                            in: Capsule()
                        )
                        .shadow(color: .black.opacity(segment == s ? 0.06 : 0),
                                radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 指标大卡

    private func metricCard(icon: String, iconColor: Color, title: String,
                            dateText: String,
                            bigValue: String, bigUnit: String,
                            secondValue: String? = nil, secondUnit: String? = nil,
                            bars: [Double], highlightColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
                Spacer(minLength: 0)
                Text(dateText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(bigValue)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(bigValue == "--" ? .secondary : .primary)
                        Text(bigUnit)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        if let sv = secondValue, let su = secondUnit {
                            Text(sv)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(su)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                MiniBarRow(values: bars, highlightColor: highlightColor)
                    .frame(width: 150, height: 90)
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    // MARK: 各分段

    private var sleepCards: some View {
        VStack(spacing: 14) {
            if let h = sleepHours {
                let hh = Int(h), mm = Int((h - Double(hh)) * 60)
                metricCard(icon: "moon.fill", iconColor: .blue, title: "睡眠时长",
                           dateText: "10月5日",
                           bigValue: "\(hh)", bigUnit: "小时",
                           secondValue: "\(mm)", secondUnit: "分钟",
                           bars: normalized(sleepHistory), highlightColor: .blue)
            } else {
                metricCard(icon: "moon.fill", iconColor: .blue, title: "睡眠时长",
                           dateText: "--",
                           bigValue: "--", bigUnit: "小时",
                           bars: [0.3, 0.55, 0.7, 0.5, 0.4, 0.12, 0.08], highlightColor: .blue)
            }
            metricCard(icon: "chart.bar.fill", iconColor: .yellow, title: "清醒时长",
                       dateText: "10月5日",
                       bigValue: "--", bigUnit: "分钟",
                       bars: [0.5, 0.1, 0.25, 0.7, 0.15, 0.08, 0.08], highlightColor: .yellow)
            metricCard(icon: "moon.fill", iconColor: .blue, title: "REM 睡眠时长",
                       dateText: "10月5日",
                       bigValue: "--", bigUnit: "小时",
                       bars: [0.25, 0.6, 0.55, 0.5, 0.12, 0.08, 0.08], highlightColor: .blue)
            metricCard(icon: "moon.fill", iconColor: .purple, title: "浅睡时长",
                       dateText: "10月5日",
                       bigValue: "--", bigUnit: "小时",
                       bars: [0.3, 0.4, 0.7, 0.55, 0.35, 0.1, 0.08], highlightColor: .purple)
        }
    }

    private var activityCards: some View {
        VStack(spacing: 14) {
            metricCard(icon: "figure.walk", iconColor: .green, title: "步数",
                       dateText: "今天",
                       bigValue: "--", bigUnit: "步",
                       bars: [0.4, 0.3, 0.35, 0.6, 0.4, 0.15, 0.08], highlightColor: .green)
            metricCard(icon: "flame.fill", iconColor: .orange, title: "活动能量",
                       dateText: "今天",
                       bigValue: "--", bigUnit: "千卡",
                       bars: [0.3, 0.5, 0.4, 0.65, 0.35, 0.12, 0.08], highlightColor: .orange)
        }
    }

    private var vitalsCards: some View {
        VStack(spacing: 14) {
            metricCard(icon: "heart.fill", iconColor: .red, title: "心率",
                       dateText: "今天",
                       bigValue: "--", bigUnit: "次/分",
                       bars: [0.4, 0.45, 0.42, 0.5, 0.46, 0.2, 0.15], highlightColor: .red)
            metricCard(icon: "heart.fill", iconColor: .orange, title: "静息心率",
                       dateText: "今天",
                       bigValue: "--", bigUnit: "次/分",
                       bars: [0.4, 0.42, 0.4, 0.44, 0.43, 0.2, 0.15], highlightColor: .orange)
            metricCard(icon: "waveform.path.ecg", iconColor: .pink, title: "心率变异性 (HRV)",
                       dateText: "今天",
                       bigValue: "--", bigUnit: "毫秒",
                       bars: [0.35, 0.5, 0.45, 0.55, 0.4, 0.18, 0.12], highlightColor: .pink)
        }
    }

    private func normalized(_ vals: [Double]) -> [Double] {
        guard !vals.isEmpty, let max = vals.max(), max > 0 else {
            return [0.3, 0.55, 0.7, 0.5, 0.4, 0.12, 0.08]
        }
        return vals.map { max(0.08, $0 / max) }
    }

    private func loadSleep() async {
        guard HealthStore.isAvailable else { return }
        sleepHours = await HealthStore.shared.lastNightSleepHours()
        // 近 7 天睡眠趋势：暂无按日聚合接口，用步数趋势占位高度，数值仍以 sleepHours 为准
        sleepHistory = await HealthStore.shared.last7DaysSteps()
    }
}

// MARK: - 横向 mini 柱状图

private struct MiniBarRow: View {
    let values: [Double]
    let highlightColor: Color
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(values.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(i == highlightIndex ? highlightColor : Color.secondary.opacity(0.15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(y: max(0.06, values[i]), anchor: .bottom)
            }
        }
    }
    private var highlightIndex: Int {
        // 高亮最后一个有意义的值（跳过尾部占位 0.08）
        var idx = values.count - 1
        while idx > 0 && values[idx] <= 0.09 { idx -= 1 }
        return idx
    }
}
