import SwiftUI

// MARK: - item10：统一加载按钮（LoadingButton）
//
// 用法：
//   @State private var saving = false
//
//   LoadingButton(title: "保存", isLoading: saving) {
//       saving = true
//       Task {
//           await doSave()          // 你的异步保存逻辑
//           saving = false
//       }
//   }
//   .buttonStyle(.borderedProminent)   // 样式（颜色/字重/圆角）仍由调用方决定，
//                                      // 本组件只管「转圈 + 禁用 + 宽度防抖」
//
// 替换示例（CloudDriveSettingsSheet.swift:282 这类写法）：
//   // 替换前
//   Button {
//       Task { await save() }
//   } label: {
//       HStack {
//           Spacer()
//           if saving { ProgressView() } else { Text("安装并授权") }
//           Spacer()
//       }
//       .font(.system(size: Typography.body, weight: .semibold))
//       .frame(maxWidth: .infinity)
//       .pill(.primary)
//   }
//   .buttonStyle(.plain)
//   .disabled(!canSave)                       // ← 注意：原写法常漏掉 .disabled(saving)，
//                                              //    loading 中还能连点
//   // 替换后
//   LoadingButton(title: "安装并授权", isLoading: saving) {
//       Task { await save() }                  // saving 的置位/复位仍由调用方管理
//   }
//   .font(.system(size: Typography.body, weight: .semibold))
//   .frame(maxWidth: .infinity)
//   .pill(.primary)
//   .buttonStyle(.plain)
//   .disabled(!canSave)
//
// 设计取舍：
//  · `isLoading` 由调用方持有（单向数据流）：组件不自己管理异步生命周期，
//    避免「组件以为完事了、调用方还在转」的双状态源；
//  · loading 时文案占位（opacity 0）+ 转圈覆盖：按钮宽度不抖，
//    原 `if/else` 切 ProgressView/Text 会让整行宽度跳一下；
//  · 自动 `.disabled(isLoading)`：防连点（原来 27 处里约一半漏了这条）；
//  · 动画用 Motion.tap（按压/小状态语义），不抢戏；
//  · 转圈用 `.controlSize(.small)`：在按钮字号下不撑高。

/// 统一加载按钮：loading 时显示转圈并禁用，宽度不抖。
struct LoadingButton: View {
    /// 按钮文案（loading 时占位保留宽度）
    let title: String
    /// 是否正在加载：true → 转圈 + 禁用
    let isLoading: Bool
    /// 点击动作（调用方负责在动作前后置位/复位 isLoading）
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .animation(Motion.tap, value: isLoading)
            .accessibilityLabel(isLoading ? "\(title)（加载中）" : title)
        }
        .disabled(isLoading)
    }
}
