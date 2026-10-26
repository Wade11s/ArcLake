# 自动归档 / Today

状态：部分证实（静态证据；未运行验证）。

## 结论
应用内教育文案明确：归档过去 12 小时未使用的标签，且可在 Settings 调整。阈值文案包括 1/6/12/24 小时、7/30 天和 never；内部标识提示阈值可按 Profile 保存。REA 确认 Clear Unpinned Tabs、View Archive、View Library 和 Restore Last Closed Tab 的菜单连接。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 498 | Clear Unpinned Tabs | 'K' | 1048576 | clearExplore: |
| 935 | View Archive | '' | None | showArchive: |
| 451 | View Library | 'L' | 1048576 | toggleLibrary: |
| 717 | Restore Last Closed Tab | 'T' | 1048576 | reopenLastTab: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3d297e0

> Arc archives tabs that you haven’t used in the past 12 hours. You can adjust this in %@Settings%@.

### 0x3cdaa10

> Auto archive threshold; 12 hours

### 0x3cda9e0

> Auto archive threshold; 24 hours

### 0x3cdaa40

> Auto archive threshold; 6 hours

### 0x3cdaa60

> Auto archive threshold; 1 hour

### 0x3cda9c0

> Auto archive threshold; 7 days

### 0x3cda9a0

> Auto archive threshold; 30 days

### 0x3cda980

> Auto archive threshold; never

### 0x3d12a10

> Manage your default search engine, Auto-Archive, and downloads in Profile Settings.

### 0x3c717a0

> autoArchiveTimeThresholdsPerProfile

## 未验证 / 限制
12 小时是未使用时长，不应改述为创建满 12 小时。文案支持默认教育口径，但未验证当前安装实际设置、计时器执行、固定标签豁免和 Library 内恢复路径。20 秒另明确标为 debugging only，不列作普通用户设置。

完整摘录：[07-auto-archive.json](07-auto-archive.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
