# Nori iOS

Nori 的原生 iOS 客户端 —— Hermes AI 服务的控制平面。

Nori 对标 Muse：个人 AI 助手，但跑在你自己的服务器上。聊天、记忆、健康、技能、MCP、智能家居 —— 所有数据都在你自己的服务上，不经过第三方云。功能比 Muse 更全（Muse 只有记忆+健康），每个功能都和 AI 联动。

## 产品定位

| | Muse / ChatGPT | Nori |
|---|---|---|
| 聊天、记忆 | ✅ | ✅（读写都通 Hermes） |
| 健康数据整合 | 部分 | ✅（HealthKit + AI 个性化建议） |
| 技能（Skills） | ✅ | ✅（官方/我的，App 内启用/禁用） |
| MCP 服务 | ❌ | ✅（App 内增删改查） |
| 智能家居 | ❌ | ✅（Home Assistant，AI 直接控制） |
| 目标管理 | ✅ | ✅（AI 从聊天识别意图自动建目标） |
| 语音朗读 | ❌ | ✅（神经语音，多厂商多音色） |
| 模型自由切换 | 固定 | ✅（多服务商多模型，App 内切换/隐藏） |
| 知识库 | ❌ | ✅（RAG，App 内管理） |
| 定时任务 | ❌ | ✅（Hermes async，后台跑） |
| 数据归属 | 第三方云 | **你自己的服务器** |
| 部署 | SaaS only | **自部署（NAS/服务器/Docker）** |

**AI 不止聊天**：Nori 能操作 —— 开关灯、设提醒、查设备、记笔记、建目标。你在对话框说一句，它调工具办了，不用给每个功能造页面。

**一个功能一个入口**：每个功能在 App 里只有一个入口，旧入口直接迁移删除，不保留两套。

## 架构

```
┌─────────────┐      ┌──────────────────────────────────┐
│  Nori App   │─────▶│           Hermes 服务            │
│ (控制平面)   │      │  ┌────────────┐  ┌───────────┐  │
└─────────────┘      │  │ Python     │  │  Hermes  │  │
                     │  │ 应用层      │  │  引擎     │  │
                     │  │ 会话/记忆/  │  │ 跑模型+  │  │
                     │  │ 任务/文件/  │  │ agent   │  │
                     │  │ TTS/看板    │  │ loop    │  │
                     │  └────────────┘  └───────────┘  │
                     └──────────────────────────────────┘
```

- **App**：Hermes 服务的控制平面。一个服务器地址、一个 API 面，对外永远只有一个 "Hermes 服务" 概念。
- **Python 应用层**（[nori-backend](https://github.com/yyyyymmmmm/nori-backend)）：会话、记忆、任务、文件、TTS、看板等所有业务 API。
- **Hermes 引擎**（`nousresearch/hermes-agent`）：跑模型和 agent loop，OpenAI 兼容接口。

**原则**：用户能配的东西（TTS key、模型选择、Home Assistant、技能、MCP）全在 App 里完成，**零 SSH**。服务端内部的东西（Hermes 上游地址/key）留在服务端，App 不感知。

## 功能详解

### 💬 聊天
- 流式 AI 对话，单气泡渲染（一段回复一个气泡）
- 语音输入（两段式，按住说话、上滑取消）
- AI 朗读回复（神经语音，可选音色）
- Agent 动作卡：AI 建目标、发邮件、设提醒时弹出确认卡
- 微信式时间戳、回到底部按钮

### 🧠 记忆
- 文件夹式记忆管理（手动添加 / 聊天记录 / 其他）
- 读：合并显示 Hermes 的 `MEMORY.md` + `USER.md`
- 写：新增记忆同步写回 Hermes，AI 下次对话就能用上
- 就地编辑、删除

### 🎯 目标
- AI 从聊天识别意图（"我想减肥"）→ 自动生成带步骤的目标 → 用户点确认建好
- 早推进 + 晚复盘（cron 自动跑）
- 步骤勾选、进度跟踪

### ❤️ 健康
- HealthKit 数据：步数、睡眠、心率、HRV
- AI 个性化建议：iOS 把健康摘要发给后端，Hermes 基于真实数据生成建议
- 健康 Hero 大卡 + 趋势

### 🔌 技能（Skills）
- 对标 Muse 技能页：官方技能 + 我的技能
- App 内启用/禁用（调后端，Hermes 即时生效）
- 未授权状态展示

### 🔧 MCP 服务
- App 内增删改查 MCP 服务器
- 启用/禁用开关
- 重启状态查看

### 🏠 智能家居
- Home Assistant 设备控制、场景
- AI 直接调工具操作（"把客厅灯打开"）
- 连接页用真实品牌图标

### 🎙️ 语音
- 神经 TTS（小米/智谱/阶跃），App 内配 key（只存后端，不回显明文）
- 多音色选择，聊天朗读

### 💡 点子 / 资讯
- AI 生成的点子（prompt 存后端，iOS 只展示）
- 今日建议（可带健康数据个性化）
- 资讯 Feed（prompt 后端管理）

### 📚 知识库
- RAG 知识库，App 内上传/管理文档
- AI 对话时自动检索

### ⏰ 定时任务
- Hermes async 后台任务
- 任务中心查看状态、取消、纠偏

## 技术栈

- **语言**：Swift 5.9+
- **UI**：SwiftUI，iOS 26 原生液态玻璃（Liquid Glass）
- **工程**：XcodeGen（`project.yml`），`qingliao/` 整体 glob，**新增 .swift 文件无需改 project.yml**
- **最低版本**：iOS 17+
- **构建**：GitHub Actions（`build-ios.yml`），unsigned IPA + SideStore 侧载

## 视觉规范

- iOS 26 原生液态玻璃 + 中性系统灰度
- `systemBackground` 白底、`label` 黑字、`secondary` #8E8E93
- **无暖色、无奶油色**（历史误记已纠正）
- 底栏：系统 tab bar，普通项灰色、选中项黑色（用户原话："一般灰色、强调黑色"）
- 所有新 UI 对标 ChatGPT/Muse 设置页质感，拒绝简单廉价
- UI 文案说人话：禁用"网关、上游、中继、凭据"等黑话
- 文案不写死 NAS（商业用户+自托管用户都要支持）

## 开发

### 分支

- `main`：**默认分支**，所有开发直接在 main，不开功能分支
- 历史分支（`native-3.0` / `native-2.0`）已冻结

### 工作流

```bash
# 1. 改完自查（确认无编译错误）
# 2. commit + push 到 main
git add -A && git commit -m "feat: xxx" && git push origin main
# 3. 手动触发 CI 出测试包（Actions → build-ios.yml → Run workflow）
```

**发版红线**：升级版本号、打 tag、正式发版必须先获得用户明确批准。测试包（分支构建）可以手动触发。

### 规范

- 同一分支同一时间只跑一个写代码的任务（并行提交曾导致 CI 连挂两次）
- 删文件前先全局搜索引用，确认无依赖再删
- 新功能三问：入口在哪？状态怎么展示？失败时用户看到什么？
- Linux 语法检查不能代替 Xcode Archive，真机验证为准

## 后端

配套后端：[nori-backend](https://github.com/yyyyymmmmm/nori-backend)（Docker 部署，`install.sh` 一键安装，App 内一键更新）。
