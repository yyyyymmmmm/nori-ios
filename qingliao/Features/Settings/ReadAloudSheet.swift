// J 线 2026-10-06：朗读声音（TTS 音色设置）。
// 从 ModelSheet 的 ttsSection 抽出：神经语音开关 + 模型/音色下拉 + 系统音色/语速。
// 读写 CloudConfig / SpeechManager，与原逻辑同一套 key。

import SwiftUI

struct ReadAloudSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var auth

    @State private var ttsOn = CloudConfig.ttsEnabled
    @State private var ttsProvider = CloudConfig.ttsProvider
    @State private var ttsModel = CloudConfig.ttsModel
    @State private var ttsVoice = CloudConfig.ttsVoice
    @State private var sysVoiceID = SpeechManager.systemVoiceID
    @State private var sysRateIndex = SpeechManager.systemRateIndex
    @State private var voiceOptions: [SpeechVoiceOption] = []
    @State private var voiceHintText = ""
    // v4.4.x：TTS 厂商 API Key 配置（后端 /api/tts/key）
    @State private var ttsKeyConfigured = false
    @State private var ttsKeyInput = ""
    @State private var ttsKeySaving = false
    @State private var ttsKeyMessage = ""

    private func ttsKeyStatusText(provider: String) -> String {
        ttsKeyConfigured ? "已配置" : "未配置（朗读会回退系统语音）"
    }

    @MainActor
    private func refreshTTSKeyStatus() async {
        ttsKeyMessage = ""
        do {
            let (data, _) = try await auth.request(
                "/api/tts/key?provider=\(ttsProvider)", method: "GET")
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = obj["ok"] as? Bool, ok {
                ttsKeyConfigured = (obj["configured"] as? Bool) ?? false
            }
        } catch {
            ttsKeyMessage = "查不到配置状态"
        }
    }

    @MainActor
    private func saveTTSKey() async {
        let key = ttsKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { ttsKeyMessage = "先填密钥"; return }
        ttsKeySaving = true
        ttsKeyMessage = ""
        do {
            let (data, _) = try await auth.request(
                "/api/tts/key", method: "POST",
                body: ["provider": ttsProvider, "api_key": key])
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = obj["ok"] as? Bool, ok {
                ttsKeyConfigured = true
                ttsKeyInput = ""
                ttsKeyMessage = "已保存"
            } else {
                ttsKeyMessage = "保存失败"
            }
        } catch {
            ttsKeyMessage = "保存失败：网络不通"
        }
        ttsKeySaving = false
    }

    private var ttsStatusText: String {
        ttsOn ? "已开启：\(CloudConfig.ttsVoicesFor(provider: ttsProvider, model: ttsModel).first { $0.id == ttsVoice }?.name ?? ttsVoice)" : "关闭（使用系统语音）"
    }

    private var ttsModelOptions: [(provider: String, model: String, label: String)] {
        CloudConfig.ttsSupported
    }

    private var ttsVoiceOptions: [(name: String, id: String)] {
        CloudConfig.ttsVoicesFor(provider: ttsProvider, model: ttsModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    GraySettingsGroup(title: "") {
                        GraySettingsToggleRow(icon: "waveform", title: "AI 语音朗读",
                                              subtitle: ttsStatusText, isOn: $ttsOn)
                            .onChange(of: ttsOn) { _, new in
                                CloudConfig.setTTsEnabled(new)
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if ttsOn {
                        GraySettingsGroup(title: "神经语音") {
                            HStack(spacing: 8) {
                                Text("模型")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Picker("", selection: Binding(
                                    get: { "\(ttsProvider)|\(ttsModel)" },
                                    set: { raw in
                                        let parts = raw.split(separator: "|", maxSplits: 1).map(String.init)
                                        let pp = parts.count > 0 ? parts[0] : ttsProvider
                                        let mm = parts.count > 1 ? parts[1] : ttsModel
                                        ttsProvider = pp; ttsModel = mm
                                        CloudConfig.setTTs(provider: pp, model: mm)
                                        let def = CloudConfig.ttsVoicesFor(provider: pp, model: mm).first?.id ?? ""
                                        ttsVoice = def
                                        CloudConfig.setTTsVoice(def)
                                    }
                                )) {
                                    ForEach(ttsModelOptions.indices, id: \.self) { idx in
                                        let opt = ttsModelOptions[idx]
                                        Text(opt.label).tag("\(opt.provider)|\(opt.model)")
                                    }
                                }
                                .pickerStyle(.menu)
                                .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            MuseRowDivider()
                            HStack(spacing: 8) {
                                Text("音色")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Picker("", selection: $ttsVoice) {
                                    ForEach(ttsVoiceOptions, id: \.id) { v in
                                        Text(v.name).tag(v.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .lineLimit(1)
                                .onChange(of: ttsVoice) { _, new in
                                    CloudConfig.setTTsVoice(new)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            MuseRowDivider()
                            // v4.4.x：TTS 厂商 API Key（后端 /api/tts/key），按当前所选模型对应厂商
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text("密钥")
                                        .font(.system(size: 17))
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 8)
                                    Text(ttsKeyStatusText(provider: ttsProvider))
                                        .font(.system(size: 15))
                                        .foregroundStyle(ttsKeyConfigured ? .green : .orange)
                                }
                                SecureField("粘贴 \(ttsModelOptions.first { "\($0.provider)|\($0.model)" == "\(ttsProvider)|\(ttsModel)" }?.label ?? "厂商") API Key", text: $ttsKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                HStack {
                                    if !ttsKeyMessage.isEmpty {
                                        Text(ttsKeyMessage)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    Button(ttsKeySaving ? "保存中…" : "保存密钥") {
                                        Task { await saveTTSKey() }
                                    }
                                    .disabled(ttsKeySaving || ttsKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 16)
                    } else {
                        GraySettingsGroup(title: "系统语音") {
                            HStack(spacing: 8) {
                                Text("系统音色")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Picker("", selection: $sysVoiceID) {
                                    Text("自动（最自然可用）").tag("")
                                    ForEach(voiceOptions) { opt in
                                        Text(opt.label).tag(opt.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .lineLimit(1)
                                .onChange(of: sysVoiceID) { _, new in
                                    SpeechManager.setSystemVoiceID(new)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            MuseRowDivider()
                            HStack(spacing: 8) {
                                Text("语速")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $sysRateIndex) {
                                    Text("慢").tag(0)
                                    Text("标准").tag(1)
                                    Text("快").tag(2)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                                .onChange(of: sysRateIndex) { _, new in
                                    SpeechManager.setSystemRateIndex(new)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 16)
                        Text("增强 / 优质语音包只能在 iOS 设置里下载，App 不能代下。")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("朗读声音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
            .task {
                // v3.9.10 口径：系统音色列表只在 onAppear 异步取一次快照，不在 body 里枚举
                let opts = await SpeechManager.voiceCatalog()
                voiceOptions = opts
                await refreshTTSKeyStatus()
            }
            .onChange(of: ttsProvider) { _, _ in
                Task { await refreshTTSKeyStatus() }
            }
        }
    }
}
