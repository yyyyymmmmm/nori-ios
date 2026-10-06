// MARK: - 引导 ④ 开启能力
//
// 日历 / 提醒事项 / 健康聚合一屏，收益句式。
// pre-permission 口径：点"开启"才调系统 requestAccess；
// 用户拒绝后不再重复弹窗（状态变为"已拒绝"，点按跳系统设置）。
// 通知权限不在这里要（just-in-time，留到首次对话后）。

import SwiftUI
import UIKit

struct OnboardingPermissionsView: View {
    @Binding var granted: Set<AppCapability>
    var onNext: () -> Void = {}
    var onSkip: () -> Void = {}

    @State private var states: [AppCapability: PermissionState] = [:]
    @State private var requesting: AppCapability?

    /// 本屏只收三项：日历 / 提醒事项 / 健康
    private let items: [AppCapability] = [.calendar, .reminders, .health]

    /// 收益句式（不说"需要权限"，说"能帮你什么"）
    private func benefit(for c: AppCapability) -> String {
        switch c {
        case .calendar: return "开会前提醒你，帮你找空闲时间"
        case .reminders: return "主动跟进你没做完的事"
        case .health: return "结合运动和睡眠，给更贴心的建议"
        default: return c.blurb
        }
    }

    /// 行内图标（SF Symbols 灰色线条，与 App 内权限页同口径）
    private func symbol(for c: AppCapability) -> String {
        switch c {
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .health: return "heart"
        default: return c.sfSymbol
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button("稍后") { onSkip() }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            OnboardingTitleBlock(
                title: "开启这些，\nNori 才能帮你",
                subtitle: "每项都只在你点「开启」后才申请，随时可以在设置里关掉。"
            )
            .padding(.top, 8)

            ForEach(items, id: \.self) { cap in
                permissionRow(cap)
                    .padding(.top, 12)
            }

            Spacer()

            OnboardingPrimaryButton(title: "下一步", action: onNext)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .task {
            // 进屏先查现状：已授权的不再打扰
            for cap in items {
                let st = await AppPermissionKit.status(of: cap)
                states[cap] = st
                if st == .granted { granted.insert(cap) }
            }
        }
    }

    // MARK: - 单行

    @ViewBuilder
    private func permissionRow(_ cap: AppCapability) -> some View {
        let st = states[cap] ?? .notDetermined
        HStack(spacing: 13) {
            Image(systemName: symbol(for: cap))
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(cap.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Text(benefit(for: cap))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)

            rowButton(cap, state: st)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func rowButton(_ cap: AppCapability, state: PermissionState) -> some View {
        switch state {
        case .granted:
            // 已授权：静态展示，不再可点
            Text("已开启")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGray5))
                .clipShape(Capsule())
        case .denied, .restricted:
            // 拒绝过：系统框弹不出来了，只能跳设置（且只在用户主动点时跳）
            Button("去设置") { openSystemSettings() }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGray6))
                .clipShape(Capsule())
        case .unavailable:
            Text("不可用")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        case .notDetermined:
            Button {
                Task { await requestPermission(cap) }
            } label: {
                if requesting == cap {
                    ProgressView().controlSize(.small)
                } else {
                    Text("开启")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .label))
            .clipShape(Capsule())
            .disabled(requesting != nil)
        }
    }

    // MARK: - 动作

    /// 点"开启"才弹系统框（Apple HIG pre-permission 口径）
    private func requestPermission(_ cap: AppCapability) async {
        requesting = cap
        defer { requesting = nil }
        let st = await AppPermissionKit.request(cap)
        states[cap] = st
        if st == .granted { granted.insert(cap) }
        // denied/restricted：不再重复弹窗，行按钮自动变为"去设置"
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }
}
