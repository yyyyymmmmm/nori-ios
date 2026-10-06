// MARK: - 目标 → 待办 的桥（打通口径：拆出的步骤直接进待办清单）
//
// K 线 2026-10-06：从已删除的 GoalsSection.swift 抽出——桥被 AgentActionExecutor /
// ChatView / GoalsTab 三处活代码使用，不能随死 view 一起删。

import Foundation

/// ⚠️ 必须标 @MainActor：桥直接摸 `TodoStore.shared` / `GoalStore.shared`（都是
/// @MainActor @Observable 单例）。不标的话，即使调用方包了
/// `await MainActor.run { ... }`，编译器仍判定桥体本身是 nonisolated →
/// CI Archive 报 "main actor-isolated static property 'shared' can not be
/// referenced from a nonisolated context"。这类错误 -parse 查不出来。
@MainActor
enum GoalTodoBridge {
    /// 目标在待办里的识别标记
    static func marker(for goal: GoalItem) -> String { "［目标·\(goal.title)］" }

    /// 步骤进待办时的标题
    static func todoTitle(step: GoalStep, goal: GoalItem) -> String {
        "\(marker(for: goal))\(step.title)"
    }

    /// 建目标时把 AI 拆的步骤灌进待办清单（用户口径：打通）。
    /// 标记已同步，避免下次编辑目标时重复灌一遍。
    static func pushStepsToTodo(_ g: GoalItem) {
        let ts = TodoStore.shared
        for s in g.steps where !s.todoLinked {
            _ = ts.add(content: todoTitle(step: s, goal: g), source: "goal")
        }
        GoalStore.shared.mutate(g.id) { item in
            for i in item.steps.indices { item.steps[i].todoLinked = true }
        }
    }

    /// 步骤完成态 → 同步待办清单。
    /// ⚠️ 用 `step.done` 判方向，**不用 toggle** —— toggle 在「想勾成未勾」时会反向。
    /// 放在桥里（而非 GoalsSection 的 private 方法）是因为 AgentActionExecutor 也要用。
    static func syncStepDone(step: GoalStep, goal: GoalItem) {
        let m = marker(for: goal)
        let ts = TodoStore.shared
        for t in ts.todos where t.content.contains(m) && t.content.contains(step.title) {
            if t.done != step.done { ts.toggleDone(t) }
        }
    }

    /// 按 id 同步（执行器用：手上只有 goalID/stepID）
    static func syncStepDone(goalID: String, stepID: String) {
        guard let g = GoalStore.shared.goals.first(where: { $0.id == goalID }),
              let s = g.steps.first(where: { $0.id == stepID }) else { return }
        syncStepDone(step: s, goal: g)
    }
}
