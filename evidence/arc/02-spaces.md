# Spaces（空间）

状态：部分证实（静态证据；未运行验证）。

## 结论
REA 确认新建、管理、重命名空间与 editSpaceTheme:、前后切换入口；补充文本将文件夹和固定标签操作限定在当前 Space。主菜单下一/上一空间绑定 ⌘⌥右/左方向键。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 1195 | New Space… | '' | None | newSpace: |
| 554 | Manage Spaces… | '' | None | toggleSpaceManager: |
| 442 | Rename Space | '' | None | renameFocusedSpace: |
| 1424 | Edit Theme… | '' | None | editSpaceTheme: |
| 808 | Next Space | '\uf703' | 1572864 | nextSpace: |
| 1108 | Previous Space | '\uf702' | 1572864 | previousSpace: |
| 334 | Reset all tabs in this Space | '' | None | resetVisiblePinnedTabs: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3c653a0

> Edit Space theme

### 0x3cd8790

> Which Spaces should use this Profile?

### 0x3d16e40

> Expand all folders in your current space.

### 0x3d169b0

> Resets all your pinned tabs in the current Space.

### 0x3d15660

> Description for Space-switching shortcut. The argument is an ordinal, e.g. “1st” in “1st Space”.

## 未验证 / 限制
底部切换控件、Ctrl+数字的实际默认映射和各 Space 的持久化独立性未运行验证。数字空间快捷键只发现描述文本。

完整摘录：[02-spaces.json](02-spaces.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
