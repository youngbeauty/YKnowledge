# Web Shader Extractor

- 来源：[Skill 说明页](https://shyft.ai/skills/web-shader-extractor)
- 源仓库：[lixiaolin94/skills](https://github.com/lixiaolin94/skills)
- 主题：网页图形与可视化
- 类型：WebGL / Canvas / shader 提取 Skill
- 当前状态：专项候选；本地尚未安装或审计

## 简介

这个 Skill 面向网页视觉效果研究：通过 Chrome DevTools 的运行时拦截能力，捕获 WebGL、Canvas 和 shader 相关信息，再帮助分析或重建渲染流程。

## 主要内容

- 捕获 shader 编译、帧缓冲、uniform 和 draw call。
- 梳理网页中的 WebGL / Canvas 渲染管线。
- 将效果整理为原生 JavaScript 或前端框架项目。
- 辅助研究和复刻网页中的视觉效果。

## 适合场景

- 研究网页上的 WebGL 视觉效果。
- 把 Canvas 或 shader 效果整理成独立 Demo。
- 做网页视觉参考和图形工程实验。

## 安装入口

    npx skills add https://github.com/lixiaolin94/skills --skill web-shader-extractor

## 注意

提取第三方网页效果不等于获得素材、代码或商业使用权。使用前应确认目标网站的授权范围，并在隔离项目中测试浏览器自动化和脚本权限。
