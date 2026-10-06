import SwiftUI

// MARK: - item8：Sheet 规范（注释形式，全仓统一口径）
//
// 一、detent（高度档位）
//  · 一般用 [.medium()] 或 [.large()]；内容是整页（设置/会话搜索/看板详情）用 [.large()]；
//  · 定高内容（输入弹窗/确认/短列表）用固定 detent [.medium()]，不要让系统按内容自适应
//    （自适应高度 + 键盘弹起 = 高度跳变，用户实测报过）；
//  · 需要两档可变的（长文本/可展开）才用 [.medium(), .large()]；
//  · detent 声明在**被弹出的内容视图 body 内**（与内容同文件），弹出处不再重复声明 ——
//    同一 sheet 两处各写一份，改了一处忘了另一处就会漂移。
//
// 二、圆角
//  · 统一用 Radius.card（16）或系统默认；不要 .presentationCornerRadius(28) 这类自定义值 ——
//    全仓只有一套视觉语言（架构纪律 4），sheet 圆角不许自创第二档。
//
// 三、拖拽指示器
//  · 一律显式声明 .presentationDragIndicator(.visible) ——
//    系统默认是 automatic（多档位/非最大档才显示），用户靠它判断「这张能不能滑」；
//  · 不要 .hidden（FeedTab 提示词 sheet 曾 hidden，已列入整改清单）。
//
// 四、可下滑关闭
//  · 默认可下滑关闭，不加 interactiveDismissDisabled；
//  · 唯一例外：关闭会丢数据且无法恢复的进行中态（录音中/汇总中/编辑未保存），
//    此时才 interactiveDismissDisabled(true)，且必须配显式关闭按钮 + 二次确认
//    （HabitSection/TodoSection/MemoSection 详情编辑态是现有合规例子）。
//
// 五、宿主纪律（老坑）
//  · 同一宿主不要并存两个可能同时为真的 .sheet —— 只有最后一条生效，另一条静默打不开
//    （DockTabView quickCapture/translateResult 两条互斥是合规例子：任一条路都先收掉另一条）；
//  · 长链 body 上挂 sheet 请走既有折叠（DockTabChromeN / chatBodyChromeN），
//    不要在巨型链上直接加带闭包的修饰符（CI 类型检查超时红线，run #571）。
//
// 六、本次 survey 结论（2026-10-07，108 个 .sheet + 24 个 fullScreenCover 抽查）
//  · 系统性问题：全仓几乎没有任何 sheet 声明 .presentationDragIndicator(.visible)
//    （仅 DashboardView:1383 一处显式 visible，FeedTab:246 一处显式 hidden）；
//  · detent 口径基本统一（多数内容视图自带 [.medium]/[.medium,.large]/[.large]）；
//  · 最离谱的 10 个见本 worker 报告（item8 节），DockTabView 的 4 张已按本规范修好。

/// 占位：本文件只承载注释规范，无运行时代码。
/// （留一个空 enum 避免"文件无声明"告警，也给将来 sheet 工具函数留命名空间。）
enum SheetConventions {
    /// 规范摘要：detent [.medium()]/[.large()]、圆角 Radius.card 或系统默认、
    /// 指示器一律 visible、默认可下滑关闭。详见文件头注释。
    static let summary = "detent:[.medium()]/[.large()], radius:Radius.card/system, indicator:.visible, dismiss:swipeable"
}
