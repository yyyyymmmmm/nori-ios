import SwiftUI

enum HealthDataSegment: String, CaseIterable {
    case sleep = "睡眠"
    case activity = "活动"
    case vitals = "生命体征"
}

/// HealthKit-backed details. Values remain unavailable until HealthKit can return real samples.
struct HealthDataView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var segment: HealthDataSegment
    @State private var sleep: Double?
    @State private var steps: Double?
    @State private var energy: Double?
    @State private var heart: Double?
    @State private var restingHeart: Double?
    @State private var hrv: Double?
    @State private var canRead = false
    @State private var loading = true

    init(initialSegment: HealthDataSegment = .sleep) {
        _segment = State(initialValue: initialSegment)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("健康数据类别", selection: $segment) {
                    ForEach(HealthDataSegment.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if !HealthStore.isAvailable {
                    ContentUnavailableView("此安装暂不可读取 Apple 健康", systemImage: "heart.slash",
                                           description: Text("当前设备或安装包未提供 HealthKit 能力。"))
                } else if !canRead {
                    ContentUnavailableView {
                        Label("尚未读取到健康数据", systemImage: "heart.text.square")
                    } description: {
                        Text("请在系统健康权限中允许 Nori 读取对应项目；HealthKit 不会向应用公开单项读取权限状态。")
                    } actions: {
                        Button("请求健康数据访问") {
                            Task { canRead = await HealthStore.shared.requestAccess(); await load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    switch segment {
                    case .sleep:
                        metric("睡眠时长", value: hoursText(sleep), unit: "昨晚")
                    case .activity:
                        metric("步数", value: steps.map { Int($0).formatted() } ?? "暂无记录", unit: "今天")
                        metric("活动能量", value: energy.map { Int($0).formatted() } ?? "暂无记录", unit: "千卡 · 今天")
                    case .vitals:
                        metric("心率", value: heart.map { Int($0.rounded()).formatted() } ?? "暂无记录", unit: "次/分 · 今日平均")
                        metric("静息心率", value: restingHeart.map { Int($0.rounded()).formatted() } ?? "暂无记录", unit: "次/分")
                        metric("心率变异性", value: hrv.map { Int($0.rounded()).formatted() } ?? "暂无记录", unit: "毫秒 · SDNN")
                    }
                    Text("数据来自此 iPhone 的 Apple 健康。空值表示所选时间范围内没有可读取的记录。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("健康数据")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .task { await load() }
        .refreshable { await load() }
    }

    private func metric(_ title: String, value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(unit).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(value).font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(value == "暂无记录" ? Color.secondary : Color.primary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color(white: 0.14) : Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func hoursText(_ value: Double?) -> String {
        guard let value else { return "暂无记录" }
        let minutes = Int((value * 60).rounded())
        return "\(minutes / 60) 小时 \(minutes % 60) 分"
    }

    private func load() async {
        guard HealthStore.isAvailable else { loading = false; return }
        loading = true
        defer { loading = false }
        let store = HealthStore.shared
        async let s = store.lastNightSleepHours()
        async let st = store.todaySteps()
        async let en = store.todayActiveEnergy()
        async let hr = store.todayHeartRate()
        async let rhr = store.todayRestingHeartRate()
        async let variability = store.todayHRV()
        sleep = await s
        steps = await st
        energy = await en
        heart = await hr
        restingHeart = await rhr
        hrv = await variability
        canRead = sleep != nil || steps != nil || energy != nil || heart != nil || restingHeart != nil || hrv != nil
    }
}
