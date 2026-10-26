# Pinned Tabs（固定标签）

状态：部分证实（静态证据；未运行验证）。

## 结论
REA 确认 Pin/Unpin Tab → toggleSelectedItemsPinned:（⌘D）、固定区域展开/折叠和 Rename Current Item。补充文本存在固定到 Space、固定到 Folder 的动作。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 181 | Pin/Unpin Tab | 'd' | 1048576 | toggleSelectedItemsPinned: |
| 142 | Rename Current Item | '' | None | rename: |
| 617 | Expand Pinned Section | '' | None | expandPinnedSection: |
| 840 | Collapse Pinned Section | '' | None | collapsePinnedSection: |
| 334 | Reset all tabs in this Space | '' | None | resetVisiblePinnedTabs: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3d18580

> Pin tabs to save for later

### 0x3d15d20

> Moves all your unpinned tabs to the Archive.

### 0x3d05ab0

> Action to move this tab to a pinned section of a space.

### 0x3d05cd0

> Action to pin this tab to a folder

## 未验证 / 限制
Rename 是通用项命令，尚未实测固定标签重命名。清理未固定标签不等于证明自动归档调度器永远排除固定标签；该规则仍待代码路径或运行测试。

完整摘录：[05-pinned-tabs.json](05-pinned-tabs.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
