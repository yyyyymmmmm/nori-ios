import SwiftUI

// MARK: - 健康"今天"页（对标参考设计）
//
// 数据：HealthStore 结构化查询；读不到显示 "--" 占位，不编假数据。
// 点"查看全部健康数据"进 HealthDataView（三级页）。

struct HealthBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAllData = false
    @State private var destinationSegment: HealthDataSegment = .sleep
    @State private var steps: Int?
    @State private var sleepText: String?
    @State private var restingHeart: Int?
    @State private var hrv: Int?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    metricGrid
                    allDataLink
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
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("返回")
                }
            }
            .navigationDestination(isPresented: $showAllData) {
                HealthDataView(initialSegment: destinationSegment)
            }
            .refreshable { await loadMetrics() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await loadMetrics() } }
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
        // 2026-10-07：深色适配
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.12),
                        Color(red: 0.10, green: 0.11, blue: 0.14),
                        Color(red: 0.12, green: 0.12, blue: 0.14)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.94, blue: 0.98),
                        Color(red: 0.96, green: 0.96, blue: 0.97),
                        Color(red: 0.985, green: 0.975, blue: 0.96)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    // 2026-10-07：卡片背景深色适配
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.14) : Color.white
    }

    // MARK: 2x2 指标卡

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            metricCard(icon: "moon.fill", iconColor: .blue, title: "睡眠",
                       value: sleepText ?? "暂无数据", unit: "昨晚", segment: .sleep)
            metricCard(icon: "heart.fill", iconColor: .orange, title: "静息心率",
                       value: restingHeart.map { "\($0)" } ?? "暂无数据", unit: "次/分", segment: .vitals)
            metricCard(icon: "waveform.path.ecg", iconColor: .pink, title: "HRV",
                       value: hrv.map { "\($0)" } ?? "暂无数据", unit: "毫秒", segment: .vitals)
            metricCard(icon: "figure.walk", iconColor: .blue, title: "步数",
                       value: steps.map { Int($0).formatted() } ?? "暂无数据", unit: "步 · 今天", segment: .activity)
        }
    }

    private func metricCard(icon: String, iconColor: Color, title: String,
                            value: String, unit: String, segment: HealthDataSegment) -> some View {
        Button {
            destinationSegment = segment
            showAllData = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: icon).foregroundStyle(iconColor)
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                Text(value).font(.system(size: 24, weight: .bold)).foregroundStyle(value == "暂无数据" ? .secondary : .primary)
                    .lineLimit(2).minimumScaleFactor(0.8)
                Text(unit).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .padding(16)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // MARK: 查看全部链接

    private var allDataLink: some View {
        Button { showAllData = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
                Text("查看健康数据")
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

    // MARK: 数据

    private func loadMetrics() async {
        guard HealthStore.isAvailable else { return }
        let store = HealthStore.shared
        async let s = store.todaySteps()
        async let sl = store.lastNightSleepHours()
        async let rh = store.todayRestingHeartRate()
        async let variability = store.todayHRV()
        if let v = await s { steps = Int(v.rounded()) }
        if let v = await rh { restingHeart = Int(v.rounded()) }
        if let v = await variability { hrv = Int(v.rounded()) }
        if let hours = await sl {
            let hh = Int(hours)
            let mm = Int((hours - Double(hh)) * 60)
            sleepText = "\(hh) 小时 \(mm) 分钟"
        }
    }
}

