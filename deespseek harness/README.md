# DeepSeek Harness（dsh）

> 目录名按入库时的拼写保留为 `deespseek harness`。产品名是 **DeepSeek Harness**，命令是 `dsh`。
> 整理日期：2026-08-15。产品当时是 Developer Preview（npm `@deepseek-ai/dsh` 约 `0.1.0-rc.6`），会破兼容。

把模型变成能在你电脑上干活的 Agent 的那一层。开箱能当编程助手用；真正定位是可拆开重组的 Agent 底板，不是再做一个 Claude Code。

## 丢给 agent 怎么用

```
读 /Users/oix/dev3/YKnowledge/deespseek harness/README.md
再读 01 和 02，然后指导我在这台电脑上把 dsh 跑起来。
```

只要概念：读 `01`。只要上手：读 `02`。纠结要不要改它：读 `03`。要社区实测和和别的 harness 对比：读 `04`。想用订阅顶掉 API key、或界面上没有思考强度选项：读 `05`。要官方原文：进 `官方文档/`。

## 一句话

**Agent = 模型 + Harness。** 模型负责想。Harness 负责读仓库、改文件、跑命令、问你审批、记下每一步。

| | 像什么 |
|---|---|
| Claude Code / Codex / Cursor | 装好的整机，打开就干活 |
| dsh | Linux 最小系统。自带能用的 Web UI，主板和驱动都能拔 |

## 文档索引

| 文档 | 内容 | 什么时候读 |
|---|---|---|
| [01-它是什么.md](01-它是什么.md) | 是什么、不是什么、四种模式、和整机的差别 | 先建立概念 |
| [02-怎么用.md](02-怎么用.md) | 安装、配模型、选工作区、第一条任务、headless、Python | 要上手 ⭐ |
| [03-改它能干嘛.md](03-改它能干嘛.md) | 改零件能多出什么、什么时候该改、什么时候别改 | 纠结要不要改 |
| [04-社区实测与对比.md](04-社区实测与对比.md) | X / HN 真实用法、Composio 换壳成绩、和 Claude Code 比 | 要证据 |
| [05-接VibeProxy与思考强度.md](05-接VibeProxy与思考强度.md) | 用订阅代替 API key（仅 macOS）、配 `reasoningEfforts`、实测档位有没有用 | 不想另买 key，或没有思考强度选项 |
| [官方文档/](官方文档/) | 从官方仓库拉下来的中文原文（README、Web、模型、CLI、架构、写插件） | 要对原文 |
| [官方文档/来源.md](官方文档/来源.md) | 官方链接和拉数日期 | 核对过期 |

**最短路径**：只想跑通 → `02`。出错了对照 `官方文档/用户指南-配置模型.md`。

## 30 秒预览

```bash
npx @deepseek-ai/dsh web
# 打开 http://127.0.0.1:3080
# 设置 → 模型 → 填 DeepSeek API Key
# 选择工作区 → 选一个 git 项目
# 标准模式，先只读，再让它改
```

## 和这个库其他目录的关系

这是一份产品调研 + 官方文档镜像，不是本机已经配好的 skill。配完如果沉淀出自己的 preset / 插件，再另开一篇实践笔记。
