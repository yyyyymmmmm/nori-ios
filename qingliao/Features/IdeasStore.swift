import SwiftUI

// MARK: - H 线：点子 = AI 动态推荐（对标 Muse 点子页）
//
// 打开页时调 AI 生成个性化推荐（QingliaoIntentClient.oneShot：非流式一次问答，
// 不进聊天会话、不落库）；同日缓存 + 下拉刷新强制刷；后端/AI 不通 → 回退内置
// 6 类模板（只做兜底，不再是主数据源）。

/// 一条 AI 推荐：标题 + 灰色详细描述 + 点开后填进对话框的完整提示词
struct AIdea: Identifiable, Codable, Sendable {
var id: String
var icon: String
var title: String
/// 2-3 句详细描述（完整提示词的摘要版，卡片上灰色显示）
var desc: String
/// 点卡片后填进对话输入框的完整提示词（详细全面，用户自己发送）
var prompt: String
/// 分组名（如"效率提升"），可空
var group: String?

init(id: String = UUID().uuidString, icon: String, title: String,
desc: String, prompt: String, group: String? = nil) {
self.id = id
self.icon = icon
self.title = title
self.desc = desc
self.prompt = prompt
self.group = group
}

enum CodingKeys: String, CodingKey { case id, icon, title, desc, prompt, group}

/// AI 只返回 JSON，不管有没有 id/group 都要解得出来
init(from decoder: Decoder) throws {
let c = try decoder.container(keyedBy: CodingKeys.self)
id = (try? c.decode(String.self, forKey:.id))?? UUID().uuidString
icon = (try? c.decode(String.self, forKey:.icon))?? "lightbulb"
title = (try? c.decode(String.self, forKey:.title))?? ""
desc = (try? c.decode(String.self, forKey:.desc))?? ""
prompt = (try? c.decode(String.self, forKey:.prompt))?? ""
group = try? c.decode(String.self, forKey:.group)
}
}

private enum IdeasError: Error { case badJSON}

@Observable @MainActor
final class IdeasStore {
static let cacheKey = "qingliao_ideas_cache_v1"
static let dateKey = "qingliao_ideas_date_v1"

var ideas: [AIdea] = []
var isLoading = false
/// 当前展示的是兜底模板（AI/后端不通）
var isFallback = false

/// 打开页时调：同日有缓存直接用；force = 下拉刷新
func refresh(force: Bool = false) async {
if!force, isCacheFresh, let cached = loadCache(),!cached.isEmpty {
ideas = cached
isFallback = false
return
}
isLoading = true
defer { isLoading = false}
do {
let list = try await generate()
ideas = list
isFallback = false
saveCache(list)
} catch {
// AI/后端不通：先吃旧缓存，再没有才用兜底模板（诚实，不编造"AI 生成"）
if let cached = loadCache(),!cached.isEmpty {
ideas = cached
isFallback = false
} else {
ideas = Self.fallbackTemplates
isFallback = true
}
}
}

// MARK: - AI 生成（走既有 oneShot 通道，不新造网络层）

private func generate() async throws -> [AIdea] {
let auth = AuthStore()
let df = DateFormatter()
df.locale = Locale(identifier: "zh_CN")
df.dateFormat = "M月d日 EEEE"
let prompt = """
你是轻聊的生活助手。今天是\(df.string(from: Date()))。请为用户生成 4-6 条个性化推荐（点子）：每条都是你现在就能帮用户做的具体事项，要实用、具体，贴合一天中的这个时间点。
每条推荐包含：icon（SF Symbol 名）、title（简短有力的标题）、desc（2-3 句话，详细说明你会怎么做、需要什么信息、产出什么）、prompt（用户点开后填入对话框的完整提示词，要详细全面、可直接使用）、group（分组名，从"今日效率""规划复盘""生活助手"中选一个）。
只返回 JSON 数组，不要任何其他文字。格式示例：
[{"icon":"calendar","title":"今日会议准备","desc":"……","prompt":"……","group":"今日效率"}]
icon 只能从这些里面选：list.bullet.clipboard,envelope,envelope.open,calendar,chart.line.uptrend.xyaxis,alarm,lightbulb,sparkles,bell,checkmark.circle
"""
let raw = try await QingliaoIntentClient.oneShot(prompt, auth: auth, timeout: 60)
return try Self.parseIdeas(raw)
}

private static func parseIdeas(_ raw: String) throws -> [AIdea] {
guard let s = raw.firstIndex(of: "["),
let e = raw.lastIndex(of: "]"), s < e else { throw IdeasError.badJSON}
let list = try JSONDecoder().decode([AIdea].self, from: Data(raw[s...e].utf8))
let valid = list.filter {
!$0.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
&&!$0.prompt.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
}
guard!valid.isEmpty else { throw IdeasError.badJSON}
return valid
}

// MARK: - 缓存（同日有效）

private var isCacheFresh: Bool {
let df = DateFormatter()
df.dateFormat = "yyyy-MM-dd"
return UserDefaults.standard.string(forKey: Self.dateKey) == df.string(from: Date())
}

private func loadCache() -> [AIdea]? {
guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
let list = try? JSONDecoder().decode([AIdea].self, from: data),
!list.isEmpty else { return nil}
return list
}

private func saveCache(_ list: [AIdea]) {
guard let data = try? JSONEncoder().encode(list) else { return}
UserDefaults.standard.set(data, forKey: Self.cacheKey)
let df = DateFormatter()
df.dateFormat = "yyyy-MM-dd"
UserDefaults.standard.set(df.string(from: Date()), forKey: Self.dateKey)
}

// MARK: - 兜底模板（AI/后端不通时用；描述与提示词均为详细版）

static let fallbackTemplates: [AIdea] = [
AIdea(
icon: "list.bullet.clipboard",
title: "每日优先事项简报",
desc: "每天早上，我会查看你的日历安排、未完成待办和未读消息，整理出最重要的 3-5 件事，说明每件为什么重要、建议什么时间做、开始前需要准备什么。",
prompt: "请为我生成今天的优先事项简报：先查看我今天的日历安排、未完成的待办事项和未读消息，然后按重要紧急程度列出最重要的 3-5 件事。对每件事说明：为什么它重要、建议在什么时间段处理、开始前需要准备什么。最后给一句话今日行动建议。",
group: "今日效率"
),
AIdea(
icon: "envelope",
title: "邮件今日速览",
desc: "把今天的新邮件分成四类：需要回复、需要行动、等待结果、仅供了解。每封一句话摘要，需要回复的草拟回复要点，需要行动的列出具体动作。",
prompt: "请速览我今天的新邮件：按四类整理。每封邮件给一句话摘要；需要回复的草拟回复要点；需要行动的列出具体动作和建议时间。最后提醒我有没有遗漏的重要邮件。",
group: "今日效率"
),
AIdea(
icon: "envelope.open",
title: "待回复事项检查",
desc: "翻一遍最近的邮件和消息，找出那些还等着你回复、确认或补材料的对话，按紧急程度排序，一件件列清楚。",
prompt: "请检查我有哪些待回复的事项：翻看最近的邮件和消息，找出仍需要我回复、确认或补充材料的对话。对每一项说明：对方是谁、等的是什么、已经拖了多久、建议怎么回复。按紧急程度排序。",
group: "今日效率"
),
AIdea(
icon: "calendar",
title: "今日会议准备",
desc: "提前整理今天重要会议的参会人背景、议程要点和你需要确认的问题，带着准备进会议室。",
prompt: "请帮我准备今天的会议：查看我今天的日历，找出重要会议。对每个会议整理：参会人及背景、会议议程、可能讨论的关键问题、我需要提前确认或准备的材料。按会议时间顺序排列。",
group: "今日效率"
),
AIdea(
icon: "chart.line.uptrend.xyaxis",
title: "每周项目进展汇总",
desc: "每周一把重点项目的进展、风险、阻塞和下一步整理成一份简报，同步一次心里就有数，还能列出需要你决策的事项。",
prompt: "请汇总本周的项目进展：整理我正在跟进的重点项目。对每个项目说明：本周完成了什么、当前进展、存在的风险和阻塞、下一步计划是什么。最后列出需要我决策的事项。",
group: "规划复盘"
),
AIdea(
icon: "alarm",
title: "截止事项提前检查",
desc: "提前两周扫描重要的 Deadline，把要交付的材料、依赖的人、潜在风险一次性列出来，并给出应对建议。",
prompt: "请检查未来两周的截止事项：扫描我的日历、待办和任务，找出重要的 Deadline。对每一项说明：截止时间、需要交付什么、依赖谁、当前准备情况、存在什么风险。按紧急程度排序，并给出应对建议。",
group: "规划复盘"
),
]
}
