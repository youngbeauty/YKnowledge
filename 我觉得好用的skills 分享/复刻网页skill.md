直接可复用的模板(粘贴后替换 {URL} / 补截图即可):

复刻 {URL} 这个页面。分两步走,先提取规格再写代码,不要跳过第一步。

## 第一步:提取设计规格(输出一份 DESIGN-SPEC.md,给我确认后再动手)

用浏览器打开页面,读取真实 computed style(不要靠截图目测),提取:

1. 设计 tokens
   - 颜色:背景/前景/主色/边框/muted 各层级,给出精确 hex/oklch,整理成 CSS 变量
   - 字体:font-family 完整 fallback 链、每个层级(h1/h2/body/caption)的
     font-size、font-weight、line-height、letter-spacing,单位保留原始值
   - 间距:section 之间的垂直间距、容器 max-width、水平 padding、
     组件内部 padding/gap,归纳成一个间距 scale(如 4/8/12/16/24/48/96px)
   - 圆角、阴影、边框宽度:每种出现过的值列一个 token

2. 布局骨架
   - 从上到下列出所有 section:名称、布局方式(grid/flex、列数)、断点行为
   - 标出容器宽度和对齐方式(居中/满宽/不对称)

3. 组件清单
   - 列出所有可复用组件(按钮、卡片、导航、badge…)及每个的变体和状态(hover/active)
   - 如果目标站用了可识别的组件库(shadcn/Radix/Tailwind 类名特征),指出来

4. 交互与动效
   - 滚动动画、hover 过渡、sticky 元素:触发条件、duration、easing

5. 资源
   - 图片/图标/logo 的获取方式(能下载的下载,不能的标注用什么占位)

## 第二步:实现(等我确认 spec 后)

- 技术栈:{Next.js + Tailwind / 你的栈}
- 所有 token 写进 {tailwind config / CSS 变量},禁止在组件里写魔法数字
- 组件按第一步清单逐个建,先建 token 和骨架,再填内容
- 完成后逐 section 对照原站截图自检,列出已知差异,不要宣称 100% 还原

要点(为什么这样写):

1. 强制两步走——提取 spec 和写代码分开,是复刻质量的最大杠杆。跳过 spec 直接写,agent 会目测猜值,间距和字号全是约数。
2. 要求读 computed style 而非看截图——getComputedStyle/DevTools 拿到的是精确值,截图目测误差 20% 起步。
3. 要求归纳成 scale/token 而不是罗列——罗列 50 个像素值没法复用;归纳成 8pt scale + CSS 变量才是"可复用提取"。
4. 禁止魔法数字——保证提取的 token 真的被用上,而不是提取完照样 hardcode。

下一步:把 {URL} 换成目标站,发给带浏览器工具的 agent(本机有 agent-browser skill 可直接执行第一步)。