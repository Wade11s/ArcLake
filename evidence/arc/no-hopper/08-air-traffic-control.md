# Air Traffic Control（链接路由）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
从单独字符串提升为结构证据：Rule{id,sourceComponents,destination}；urlMatch；匹配方式 matches/contains；目标 space/littleArc；持久化 version/rules/defaultDestination；存储接口 readSync/saveAsync。官方说明有包含/精确匹配、默认空间，删除 Space 同时删除相关规则。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `LinkRouting.LinkMatchingRule`

struct descriptor: `0x103c0a230`；field descriptor: `0x103d330b8`

`id`, `sourceComponents`, `destination`

### `LinkRouting.LinkSourceComponent`

struct descriptor: `0x103c0a1c0`；field descriptor: `0x103d33018`

`id`, `componentType`

### `LinkRouting.LinkSourceComponent.ComponentType`

enum descriptor: `0x103c0a1dc`；field descriptor: `0x103d33040`

`urlMatch`

### `LinkRouting.LinkSourceTextMatchingStyle`

enum descriptor: `0x103c0a1a4`；field descriptor: `0x103d32ff0`

`matches`, `contains`

### `LinkRouting.LinkDestination`

enum descriptor: `0x103c0a1f8`；field descriptor: `0x103d3305c`

`space`, `littleArc`

### `LinkRouting.LinkDestination.ProfileDestination`

enum descriptor: `0x103c0a214`；field descriptor: `0x103d33084`

`profile`, `space`, `mostRecent`

### `LinkRouting.StorableLinkRoutingState`

struct descriptor: `0x103c0a444`；field descriptor: `0x103d332b0`

`version`, `rules`, `defaultDestination`

### `LinkRouting.LinkRoutingClientDataStore`

struct descriptor: `0x103c0a0d8`；field descriptor: `0x103d32e60`

`readSync`, `saveAsync`

## 菜单 → 方法 → 机器码

本项未选择直接菜单 selector；结构证据见上。没有据此声称完成了方法调用链验证。

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Spaces: Distinct Browsing Areas — ### How to Set Up a Route

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 58 行）

> * Select URL **contains** or **is equal to** a particular URL.

### Spaces: Distinct Browsing Areas — ### How to Set Up a Route

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 60 行）

>   + **Contains** will route links that contains your text entry, even it's not an exact match. Great options for "*Contains*" are website domains. For example, if you create a Route for URL's that contain "spotify.com", this Spotify link\* will Route automatically to your Music Space. (\*This is a favorite album from our teammate, Brian!)

### Arc for macOS - 2023 Release Notes — ## November 30, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 69 行）

> * Arc v1.19.1 contains an important security fix for a Chromium vulnerability. We strongly recommend updating to Arc v1.19.1 as soon as you can, as it is based on Chromium 119.0.6045.199, which contains this fix. Update and stay safe out there!

### Arc for macOS - 2023 Release Notes — ## September 14, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 206 行）

> * Arc v1.8.0 contains an important security fix for a Chromium vulnerability. We strongly recommend updating to Arc v1.8.0 as soon as you can, as it is based on Chromium v116.0.5845.187, which contains this fix. Update and stay safe out there!

### Arc for macOS - 2024 - 2026 Release Notes — ## January 9, 2025 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 589 行）

> * This update contains a Chromium upgrade to 131.0.6778.265.

### Arc for macOS - 2024 - 2026 Release Notes — ## December 19, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 598 行）

> * This update contains a Chromium upgrade to 131.0.6778.205.

### Arc for macOS - 2024 - 2026 Release Notes — ## December 12, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 606 行）

> * This release contains a Chromium update to 131.0.6778.140 that includes security and stability fixes.

### Arc for macOS - 2024 - 2026 Release Notes — ## December 5, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 614 行）

> * This update contains a Chromium upgrade to 131.0.6778.109.

### Spaces: Distinct Browsing Areas — ### How to Set Up a Route

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 61 行）

>   + **Is equal to** will only route links that exactly match your text entry. Make sure to include http://www, if that's how your link loads! This is a great option for very specific URLs. For example, you may use Google Docs across all Spaces, but if should always route to your Work Space, *is equal to* is the right choice.

### Spaces: Distinct Browsing Areas — ## Route Sites to Specific Spaces with Air Traffic Control

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 44 行）

> You can also set up a default Space for links so tabs are automatically opened in the Space of your choice, rather than in Little Arc.

### Spaces: Distinct Browsing Areas — ### How to Set Up a Route

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 65 行）

> If you have a Route set up on a Space that's been deleted, the Route will be deleted as well.

### Pinned Tabs: Tabs you want to stick around — ## What are Pinned Tabs?

[官方来源](https://resources.arc.net/hc/en-us/articles/19231060187159-Pinned-Tabs-Tabs-you-want-to-stick-around) / [已保存正文](official-docs/19231060187159.md)（抽取正文第 17 行）

> * Pinned Tabs are like "Apps" in that they keep you contained within a specific site. If you pin the New York Times, for example, you can navigate anywhere on the New York Times website but clicking a link that would change the tab will open a Peek window, instead of replacing New York Times.

## 残留未知
规则顺序、大小写/URL 规范化、多个 sourceComponents 的 AND/OR、冲突优先级、所有来源覆盖范围没有获得执行路径；不能自行补成完整路由算法。

[首轮证据](../08-air-traffic-control.md) · [本轮完整 JSON](08-air-traffic-control.json) · [总报告](README.md)
