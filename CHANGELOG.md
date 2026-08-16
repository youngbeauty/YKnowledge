# 更新历史

这个库持续更新。每次加了什么、改了什么，都记在这里，最新的在最上面。

想只看新增内容，可以直接对 agent 说：「读 CHANGELOG.md，把最近新增的几篇挑出来讲给我听。」

---

## 2026-08-15

**新增：dsh 接 VibeProxy 与思考强度**
- `deespseek harness/05-接VibeProxy与思考强度.md` — macOS 上用 Claude / ChatGPT 订阅顶掉 API key 接进 dsh；解释「模型配好了却没有思考强度选项」的成因，怎么从代理里查出每个模型真实支持的档位，以及用实测验证这些档位不是摆设

**新增：DeepSeek Harness 调研**
- `deespseek harness/` — 它是什么、怎么用、改它能干嘛、社区实测与和 Claude Code / 其他 harness 的对比
- `deespseek harness/官方文档/` — 从官方仓库拉下来的中文原文（Web 指南、配模型、Python SDK、CLI、架构、写插件），2026-08-15 快照

---

## 2026-08-10

**新增**
- `个人实践经验总结/独立开发笔记/discord.md` — 独立开发的用户反馈记录
- `CHANGELOG.md` — 也就是本文件，从这次开始记录更新历史

---

## 2026-08-09

**新增：飞书 CLI 同步 skill**
- `飞书 CLI/yknowledge-feishu-sync/` — 把本地知识库增量同步到飞书云文档的 skill（只推变更文件，附 agents 配置）

**新增：README**
- 说明这个库的用法：把文章的网页链接直接丢给 AI agent，让它结合你本机环境手把手教你配

**首次发布：知识库建库**
- `个人实践经验总结/` — Claude Code 最佳实践（Output Style 替代 CLAUDE.md、skills plugin）、云端 agent 自动化（routine 监控网页、问题分诊）、独立开发笔记
- `我觉得好用的skills 分享/` — 按主题分的 skill 推荐：AI 编程工作流、UI 动效与前端设计、图片生成、知识管理、网页图形与可视化、生活方式应用、Matt Pocock skills 仓库
- `外网前沿科技AI文章摘录/` — Claude 5 上下文工程新规则、pi 的 web 工具与 computer use 使用技巧
- `飞书 CLI/` — 飞书 CLI 初步体验记录与知识库同步 skill
