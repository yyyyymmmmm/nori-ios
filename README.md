# Nori — 你的自部署 AI 助手

像 Muse 一样好用，但跑在你自己的服务器上。

Nori 是一个原生 iOS 个人 AI 助手：聊天、记忆、健康、智能家居、语音朗读——所有数据都在你自己的服务上，不经过第三方云。想要 Muse 的体验，又想要数据的完全控制，Nori 就是答案。

## 为什么是 Nori

| | Muse / ChatGPT | Nori |
|---|---|---|
| 聊天、记忆 | ✅ | ✅ |
| 健康数据整合 | 部分 | ✅（Apple Health / 华为运动） |
| 智能家居控制 | ❌ | ✅（Home Assistant） |
| 语音朗读（自选音色） | ❌ | ✅（小米/智谱/阶跃） |
| 模型自由切换 | 固定 | ✅（多服务商、多模型） |
| 数据归属 | 第三方云 | **你自己的服务器** |
| 部署 | SaaS only | **自部署（NAS/服务器/Docker）** |

**AI 不止聊天**：Nori 能操作——开关灯、设提醒、查设备、记笔记。你在对话框说一句，它调工具办了，不用给每个功能造页面。

## 架构

```
┌─────────────┐      ┌──────────────────────────────┐
│  Nori App   │─────▶│        Hermes 服务           │
│ (控制平面)   │      │  ┌────────┐   ┌───────────┐  │
└─────────────┘      │  │ Python │   │  Hermes  │  │
                     │  │ 应用层  │   │  引擎    │  │
                     │  └────────┘   └───────────┘  │
                     └──────────────────────────────┘
```

- **App**：Hermes 服务的控制平面。一个服务器地址、一个 API 面。
- **Python 应用层**：会话、记忆、任务、文件、TTS、看板等。
- **Hermes 引擎**（`nousresearch/hermes-agent`）：跑模型和 agent loop，OpenAI 兼容。

用户能配的东西（TTS 密钥、模型、Home Assistant）全在 App 里，**零 SSH**。

## 功能

- 💬 **对话**：流式 AI 聊天，语音输入/朗读
- 🧠 **记忆**：文件夹式记忆管理，AI 自动沉淀
- ❤️ **健康**：睡眠/心率/HRV/步数，Apple Health 同步
- 🏠 **智能家居**：Home Assistant 设备控制、场景
- 🎙️ **朗读**：神经语音，多厂商多音色，App 内配 key
- 🔄 **模型**：多服务商（DeepSeek/OpenAI/…），App 内切换、隐藏

## 🚀 快速上手

- 默认分支：**`main`**
- XcodeGen 工程（`project.yml`），`qingliao/` 整体 glob，**新增 .swift 文件无需改 project.yml**
- iOS 17+，iOS 26 原生液态玻璃

```bash
# 1) 改完自查 + commit
# 2) push 到 main
git push origin main
# 3) 手动触发 CI 出测试包（Actions → build-ios.yml → Run workflow）
```

**发版红线**：打 tag、正式 IPA 必须先经用户明确批准。

## 🔀 分支与版本

- `main`：**当前默认分支**，Nori 开发线（2026-10 起）
- `native-3.0` / `native-2.0`：历史版本，已冻结

## 🎨 视觉规范

- iOS 26 原生液态玻璃 + 中性系统灰度
- `systemBackground` 白底、`label` 黑字、`secondary` #8E8E93
- **无暖色、无奶油色、无手画图标**（用真实资产/SF Symbols）
- 底栏：系统 tab bar，普通项灰色、选中项黑色
- 对标 ChatGPT/Muse 设置页质感，拒绝廉价感

## 后端

配套后端：[`github.com/yyyyymmmmm/nori-backend`](https://github.com/yyyyymmmmm/nori-backend)（Docker 部署，含 compose + 部署文档）。
