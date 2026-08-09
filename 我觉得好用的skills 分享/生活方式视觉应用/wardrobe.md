# tandpfun/wardrobe

- 来源：[GitHub 仓库](https://github.com/tandpfun/wardrobe)
- 主题：生活方式视觉应用
- 类型：Web 应用 + 2 个 Codex Skill
- 当前状态：项目参考；本地尚未安装或审计

## 简介

wardrobe 是一个数字衣橱应用：用图像模型识别衣物，生成干净的商品图，并可进一步生成模特穿搭或 lookbook。它更像一个完整的可运行项目，不是通用型推荐 Skill。

## 主要内容

- 导入衣物照片并提取衣物信息。
- 用图像模型生成商品抠图和整理后的衣物图片。
- 生成模特预览、穿搭和 lookbook。
- 仓库内提供导入衣物和生成穿搭的 Codex Skill。
- 本地保存 data/library.json、导入图片和生成结果。

## 适合场景

- 研究“视觉识别 + 图像生成”的完整工作流。
- 做个人数字衣橱或穿搭管理工具。
- 参考如何把 Agent Skill 嵌入一个实际 Web 应用。

## 运行前提

- 需要配置 OPENAI_API_KEY。
- 需要准备 data/model-reference.png。
- 按 README 完成依赖安装和本地启动。

## 注意

运行会产生本地图片、JSON 和 API 调用成本。建议使用测试目录和单独的 API key，先确认数据保存位置再导入私人照片。
