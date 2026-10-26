# Air Traffic Control（链接路由）

状态：部分证实（静态证据；未运行验证）。

## 结论
应用内说明直接写明：Routes 决定特定网站在 Arc 中哪里打开，并以 Spotify 链接总是在 Personal space 打开为例；有打开 routes 的动作描述与持久化失败诊断文本。

## REA 菜单归档证据
本项未取得独立 REA 功能证据；下列为补充的二进制文本观察，不能冒称 REA 输出。

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3d04fa0

> Air Traffic Control

### 0x3d04fc0

> Action to open Air Traffic Control routes.

### 0x3d12e70

> Routes let you choose where specific sites open inside Arc. For example, you can route Spotify links to always open inside your Personal space.

### 0x3d0c850

> Assertion failure: Failed to persist Link Routing state.

## 未验证 / 限制
这不是已执行的路由测试。URL 匹配算法、规则优先级、现有标签复用、外部/内部链接覆盖范围未确定。该项没有独立 REA 路由实现证据。

完整摘录：[08-air-traffic-control.json](08-air-traffic-control.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
