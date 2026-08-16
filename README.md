# 小 Y 的个人 AI 知识库

一份持续更新的 AI 实践笔记：Claude Code 的用法、好用的 skills、外网前沿文章摘录、独立开发与自动化经验。

## 用法：把网页链接丢给你的 AI agent

这个库不是拿来「读完」的，是拿来**直接喂给 AI 用**的。

看到感兴趣的一篇，复制它的网页 URL，粘给你的 AI agent（Claude Code、Cursor、ChatGPT 都行），然后说：

```
https://github.com/youngbeauty/YKnowledge/blob/main/我觉得好用的skills%20分享/复刻网页skill.md

读一下这篇，然后指导我在我的电脑上怎么弄。
```

agent 会读完内容、结合你本机的实际情况，一步步告诉你该装什么、改哪个文件、跑哪条命令。不用自己啃文档、也不用担心版本对不上。

几个常用的说法：

- 「读这篇，然后**直接帮我配好**」——让 agent 动手，不只是讲
- 「读这篇，我用的是 Windows / 我没装 xxx，**照我的环境改一遍**」
- 「读这两篇，**哪个方案更适合我**，给个建议就行」

想整库拉下来也可以：

```bash
git clone https://github.com/youngbeauty/YKnowledge.git
```

## 目录

| 目录 | 内容 |
| --- | --- |
| `个人实践经验总结/` | Claude Code 最佳实践、云端 agent 自动化、独立开发笔记 |
| `我觉得好用的skills 分享/` | 按主题分类的 skill 推荐：AI 编程工作流、UI 动效、图片生成、知识管理、可视化等 |
| `外网前沿科技AI文章摘录/` | 英文前沿文章的摘录与要点 |
| `飞书 CLI/` | 飞书 CLI 的体验记录与知识库同步 skill |
| `deespseek harness/` | DeepSeek Harness（dsh）是什么、怎么用、为什么改、社区实测，以及官方中文文档快照 |

## 更新历史

每次加了什么内容，都记在 [CHANGELOG.md](CHANGELOG.md)，最新的在最上面。

## 说明

内容基于个人实测，写的时候有效，工具迭代快，跑不通很正常——把报错一起丢给 agent 让它帮你排。

欢迎提 issue 交流。
