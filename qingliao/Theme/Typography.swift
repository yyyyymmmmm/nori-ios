import SwiftUI
import UIKit   // v4.0.61：正文接入 Dynamic Type 用 UIFontMetrics（SwiftUI 不转发 UIKit 符号）

// MARK: - v3.9.0 全站字号令牌（Typography）
//
// 背景：改造前 `.font(.system(size: …))` 散落 **22 个不同数值**（7.5 / 8.5 / 9 / 9.5 / 10 / 10.5 / 11 / 11.5 /
// 12 / 12.5 / 13 / 13.5 / 14 / 15 / 16 / 17 / 18 / 19 / 20 / 22 / 24 / 26 / 28 / 30 / 32 / 34 / 40 / 44 / 52 / 76），
// 其中 11 / 12 / 13 三档共 424 处、彼此只差 1pt —— 视觉层级糊，是"不够精致"的主因。
//
// 目标：**文字字号收敛为 8 档语义层级**，所有语义字号都按 Dynamic Type 缩放。
//
// 语义分层（越往下越大，不要跨层乱用）：
//   tiny      角标 / 极小注释（原 7.5–10.5）
//   caption   次要说明文字（原 11–11.5）
//   subhead   列表次要文字 / 标签（原 12–13.5）
//   body      正文（原 14–15）
//   title     小标题 / 卡片数值（原 16–17）
//   headline  卡片 / 弹窗标题（原 18–20）
//   titleXL   大数字 / 突出标题（原 22–24）
//   display   空态插画 / 大标题（原 26–30）
//
// ⚠️ **装饰字号不在此体系内**：≥32 的（32 / 34 / 40 / 44 / 52 / 76）是启动页、登录页大图标、空态插画、
// 任务中心标题等一次性装饰尺寸，**保持原值不动**（SplashView 等属已定稿美术方向）。
//
// 用计算属性读取当前 UIFontMetrics，保证系统文字大小改变时共用令牌同步更新。

enum Typography {
    private static func scaled(_ value: CGFloat, style: UIFont.TextStyle) -> CGFloat {
        UIFontMetrics(forTextStyle: style).scaledValue(for: value)
    }

    /// 角标 / 极小注释
    static var tiny: CGFloat { scaled(10, style: .caption2) }
    /// 次要说明文字
    static var caption: CGFloat { scaled(11, style: .caption1) }
    /// 列表次要文字 / 标签
    static var subhead: CGFloat { scaled(13, style: .subheadline) }
    /// 正文字号：跟随系统 Dynamic Type。
    static var body: CGFloat { scaled(15, style: .body) }
    /// 小标题 / 卡片数值
    static var title: CGFloat { scaled(17, style: .headline) }
    /// 卡片 / 弹窗标题
    static var headline: CGFloat { scaled(20, style: .title3) }
    /// 大数字 / 突出标题
    static var titleXL: CGFloat { scaled(24, style: .title2) }
    /// 空态插画 / 大标题
    static var display: CGFloat { scaled(28, style: .title1) }
    /// 设置分组标题与行标题（相同语义尺寸，供系统设置式列表共用）
    static var rowTitle: CGFloat { scaled(16, style: .body) }
    /// 设置组标题
    static var groupLabel: CGFloat { scaled(15, style: .subheadline) }
    /// 设置行右侧状态/计数
    static var rowValue: CGFloat { scaled(14, style: .caption1) }
}

// MARK: - v3.9.19 全站行距令牌（LineSpacing）
//
// 背景：改造前 `.lineSpacing(…)` 的静态值散落 2 / 3 / 4 / 6 四种，同为「AI 生成长正文」却有三种手感
// （资讯正文 4、备忘录详情 6、会话导出 6）——同类文本不一致，长文阅读的松紧随场景漂移。
//
// ⚠️ **聊天会话的 AI 消息不在此体系内**：那里的行距是用户设置项 `qingliao_ai_line_spacing`
//（设置 →「AI 输出行高」滑块，紧凑↔宽松 0…6、step 0.5、默认 1.0；原 CloudSettingsView 已随云端模式移除）。
// **用户设置优先，不要换成令牌**；令牌只服务「没有设置项兜底」的静态文本。
enum LineSpacing {
    /// 长文正文（≥15pt 的连续阅读文本：资讯 AI 正文、备忘录详情 / 编辑、会话导出）
    static let long: CGFloat = 6
    /// 紧凑说明（卡片副文本、会话列表行、用户消息默认、pin 预览）
    static let compact: CGFloat = 3
}
