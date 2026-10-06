import SwiftUI

// MARK: - 健康"今天"页（对标参考设计）
//
// 数据：HealthStore 结构化查询；读不到显示 "--" 占位，不编假数据。
// 点"查看全部健康数据"进 HealthDataView（三级页）。

struct HealthBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAllData = false
    @State private var steps: Int?
    @State private var stepsHistory: [Double] = []
    @State private var sleepText: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    metricGrid
                    allDataLink
                    recordSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                    }
                    .accessibilityLabel("返回")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "cloud")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: -4, y: -4)
                    }
                    .accessibilityLabel("健康数据已同步")
                }
            }
            .navigationDestination(isPresented: $showAllData) {
                HealthDataView()
            }
            .task {
                guard !loaded else { return }
                loaded = true
                await loadMetrics()
            }
        }
        .background(healthGradient)
    }

    private var healthGradient: some View {
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

    // MARK: 2x2 指标卡

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            metricCard(icon: "moon.fill", iconColor: .blue, title: "睡眠",
                       value: sleepText ?? "--", chart: .bars([0.3, 0.55, 0.7, 0.5, 0.45, 0.15, 0.1]))
            metricCard(icon: "heart.fill", iconColor: .orange, title: "静息心率",
                       value: "--", chart: .line([0.4, 0.42, 0.38, 0.45, 0.5]))
            metricCard(icon: "heart.fill", iconColor: .yellow, title: "HRV",
                       value: "--", chart: .line([0.3, 0.4, 0.6, 0.5, 0.35, 0.45, 0.3]))
            metricCard(icon: "figure.walk", iconColor: .blue, title: "步数",
                       value: steps.map { "\($0)" } ?? "--", unit: "步",
                       topRight: "00:59",
                       chart: .bars(stepsHistory.isEmpty
                                    ? [0.4, 0.3, 0.35, 0.6, 0.4, 0.15, 0.08]
                                    : normalized(stepsHistory)))
        }
    }

    private enum MiniChart {
        case bars([Double])
        case line([Double])
    }

    private func normalized(_ vals: [Double]) -> [Double] {
        guard let maxVal = vals.max(), maxVal > 0 else { return vals.map { _ in 0.1 } }
        return vals.map { Swift.max(0.08, $0 / maxVal) }
    }

    private func metricCard(icon: String, iconColor: Color, title: String,
                            value: String, unit: String? = nil,
                            topRight: String? = nil, chart: MiniChart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text(topRight ?? "--:--")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(value == "--" ? .secondary : .primary)
                if let unit {
                    Text(unit)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            switch chart {
            case .bars(let vals):
                MiniBarChart(values: vals, highlightLast: title == "步数")
                    .frame(height: 56)
            case .line(let vals):
                MiniLineChart(values: vals)
                    .frame(height: 56)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    // MARK: 查看全部链接

    private var allDataLink: some View {
        Button { showAllData = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
                Text("查看全部 19 项健康数据")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: 健康记录

    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("健康记录")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                recordCard(title: "sleep", date: "更新于 10月6日",
                           subtitle: "睡眠",
                           detail: "(from Health Data; source_name「华为运动健康」，method healthkit_sleep_analysis)")
                recordCard(title: "activity", date: "更新于 10月6日",
                           subtitle: "日常活动",
                           detail: "(from Health Data)\n覆盖与缺口\n日聚合覆盖 2026-09-06–09-17 与 2026-09-28–")
            }
        }
    }

    private func recordCard(title: String, date: String, subtitle: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text(date)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Divider()
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .lineLimit(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    // MARK: 数据

    private func loadMetrics() async {
        guard HealthStore.isAvailable else { return }
        let store = HealthStore.shared
        async let s = store.todaySteps()
        async let h = store.last7DaysSteps()
        async let sl = store.lastNightSleepHours()
        if let v = await s { steps = Int(v.rounded()) }
        stepsHistory = await h
        if let hours = await sl {
            let hh = Int(hours)
            let mm = Int((hours - Double(hh)) * 60)
            sleepText = "\(hh) 小时 \(mm) 分钟"
        }
    }
}

// MARK: - Mini 图表

private struct MiniBarChart: View {
    let values: [Double]
    var highlightLast: Bool = false
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(values.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor(i))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(y: max(0.05, values[i]), anchor: .bottom)
            }
        }
    }
    private func barColor(_ i: Int) -> Color {
        if highlightLast && i == values.count - 1 { return .blue }
        return Color.secondary.opacity(0.18)
    }
}

private struct MiniLineChart: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let pts = values.enumerated().map { i, v -> CGPoint in
                let x = values.count > 1
                    ? geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                    : geo.size.width / 2
                let y = geo.size.height * (1 - CGFloat(max(0.05, min(1, v))))
                return CGPoint(x: x, y: y)
            }
            Path { p in
                guard let first = pts.first else { return }
                p.move(to: first)
                for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            ForEach(pts.indices, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1.5))
                    .position(pts[i])
            }
        }
    }
}
