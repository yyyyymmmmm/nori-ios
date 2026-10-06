// J 线 2026-10-06：连接应用（对标 Today「连接应用」页）。
// 标题 + 副标题；本机 / 云端分段；点按授权、用户零填写。
// 本机行复用 AppPermissionKit（状态查询 + 系统授权弹窗）；云端行跳转现有接入页。

import AVFAudio
import MediaPlayer
import SwiftUI
import UIKit

struct ConnectAppsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var segment = 0 // 0=本机，1=云端
    @State private var states: [AppCapability: PermissionState] = [:]
    @State private var musicState: PermissionState = .notDetermined
    @State private var micState: PermissionState = .notDetermined
    @State private var requesting = false

    // 云端子页
    @State private var showThirdParty = false
    @State private var showMail = false
    @State private var showCloudDrive = false
    @State private var showHA = false

    /// 本机能力（Today 口径子集；剪贴板/文件/通知等系统级项不进此页）
    private let deviceCaps: [AppCapability] = [.calendar, .reminders, .contacts, .photos, .location, .health]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Picker("", selection: $segment) {
                    Text("本机").tag(0)
                    Text("云端").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if segment == 0 {
                            Text("已授权")
                                .font(.system(size: 15))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                            GraySettingsGroup(title: "") {
                                ForEach(deviceCaps) { cap in
                                    deviceRow(cap)
                                    if cap != deviceCaps.last { MuseRowDivider() }
                                }
                                MuseRowDivider()
                                musicRow
                                MuseRowDivider()
                                micRow
                            }
                            .padding(.horizontal, 16)
                        } else {
                            Text("云端服务")
                                .font(.system(size: 15))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                            GraySettingsGroup(title: "") {
                                GraySettingsRow(icon: "square.grid.2x2", title: "对接第三方",
                                                subtitle: "微信 / Telegram / 飞书 / 钉钉…点按授权") {
                                    showThirdParty = true
                                }
                                MuseRowDivider()
                                GraySettingsRow(icon: "envelope", title: "邮件接入",
                                                subtitle: "AI 可收发邮件") {
                                    showMail = true
                                }
                                MuseRowDivider()
                                GraySettingsRow(icon: "externaldrive", title: "网盘接入",
                                                subtitle: "夸克等官方 skill 包") {
                                    showCloudDrive = true
                                }
                                MuseRowDivider()
                                GraySettingsRow(icon: "house", title: "HA 设置",
                                                subtitle: "Home Assistant") {
                                    showHA = true
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("连接应用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
            .task { await refresh() }
            .sheet(isPresented: $showThirdParty) {
                ThirdPartyView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showMail) {
                MailSettingsSheet()
                    .presentationDetents([.medium, .large])
                    .scrollContentBackground(.hidden)
            }
            .sheet(isPresented: $showCloudDrive) {
                CloudDriveSettingsSheet()
                    .presentationDetents([.medium, .large])
                    .scrollContentBackground(.hidden)
            }
            .sheet(isPresented: $showHA) {
                HASettingsSheet()
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        VStack(spacing: 4) {
            Text("连接服务与数据，让我更好地帮助你")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    // MARK: - 本机行

    @ViewBuilder
    private func deviceRow(_ cap: AppCapability) -> some View {
        let st = states[cap] ?? .notDetermined
        // 2026-10-07 真机反馈：本机页用 Apple 风格真机图标（对标 Muse），不用 SF 符号
        let appleIcon: AnyView? = cap.appleStyleKind.map { AnyView(AppleStyleIcon(kind: $0, size: 44)) }
        GraySettingsRow(icon: appleIcon == nil ? cap.sfSymbol : nil,
                        colorful: appleIcon == nil,
                        iconView: appleIcon,
                        title: cap.displayName,
                        subtitle: cap.blurb, value: st.label, chevron: false) {
            Task { await tapCapability(cap, state: st) }
        }
    }

    private var musicRow: some View {
        GraySettingsRow(iconView: AnyView(AppleStyleIcon(kind: .music, size: 44)),
                        title: "音乐",
                        subtitle: "读取媒体库，为你播放音乐", value: musicState.label, chevron: false) {
            Task { await tapMusic() }
        }
    }

    private var micRow: some View {
        GraySettingsRow(iconView: AnyView(AppleStyleIcon(kind: .mic, size: 44)),
                        title: "麦克风",
                        subtitle: "语音输入与语音对话", value: micState.label, chevron: false) {
            Task { await tapMic() }
        }
    }

    // MARK: - 授权逻辑

    private func refresh() async {
        for cap in deviceCaps {
            states[cap] = await AppPermissionKit.status(of: cap)
        }
        musicState = MPMediaLibrary.authorizationStatus().toPermissionState()
        micState = AVAudioSession.sharedInstance().recordPermission.toPermissionState()
    }

    private func tapCapability(_ cap: AppCapability, state: PermissionState) async {
        Haptics.tap()
        guard !requesting else { return }
        switch state {
        case .notDetermined:
            requesting = true
            states[cap] = await AppPermissionKit.request(cap)
            requesting = false
        case .denied, .restricted:
            openSystemSettings()
        case .granted, .unavailable:
            break
        }
    }

    private func tapMusic() async {
        Haptics.tap()
        switch musicState {
        case .notDetermined:
            await withCheckedContinuation { cont in
                MPMediaLibrary.requestAuthorization { _ in cont.resume() }
            }
            musicState = MPMediaLibrary.authorizationStatus().toPermissionState()
        case .denied, .restricted:
            openSystemSettings()
        case .granted, .unavailable:
            break
        }
    }

    private func tapMic() async {
        Haptics.tap()
        switch micState {
        case .notDetermined:
            await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { _ in cont.resume() }
            }
            micState = AVAudioSession.sharedInstance().recordPermission.toPermissionState()
        case .denied, .restricted:
            openSystemSettings()
        case .granted, .unavailable:
            break
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - 系统授权状态 → PermissionState 映射

private extension MPMediaLibraryAuthorizationStatus {
    func toPermissionState() -> PermissionState {
        switch self {
        case .authorized:    return .granted
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        @unknown default:    return .notDetermined
        }
    }
}

private extension AVAudioSession.RecordPermission {
    func toPermissionState() -> PermissionState {
        switch self {
        case .granted:      return .granted
        case .denied:       return .denied
        case .undetermined: return .notDetermined
        @unknown default:   return .notDetermined
        }
    }
}
