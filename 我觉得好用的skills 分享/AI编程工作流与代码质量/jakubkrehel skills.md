# jakubkrehel/skills

- 来源：[GitHub 仓库](https://github.com/jakubkrehel/skills)
- 主题：AI 编程工作流与代码质量
- 类型：多 Skill 公开仓库
- 当前状态：建议收录；本地尚未安装或审计

## 简介

这是一组面向界面和产品质量的 Agent Skill，重点不是生成一套固定模板，而是让 AI 在做界面、布局、文案和代码审查时，能够从多个专业角度检查结果。

## 主要内容

- better-interface：从设计、工程、可访问性和产品体验等角度做综合界面审查。
- interface-review：审查未提交修改、分支或 PR。
- better-ui、better-typography、better-colors：分别处理 UI、字体排版和颜色系统。
- better-accessibility、better-layout、better-writing：补充无障碍、布局和 UX 文案检查。

## 适合场景

- 网站或产品界面开发后的统一检查。
- 前端 PR 的可访问性、排版、颜色和布局复核。
- 想把“看起来是否专业”变成可重复的审查流程。

## 安装入口

    npx skills add jakubkrehel/skills

## 注意

安装前建议先阅读仓库中的 SKILL.md，只启用实际需要的条目，避免把整套界面审查规则全部加载进每个任务。
