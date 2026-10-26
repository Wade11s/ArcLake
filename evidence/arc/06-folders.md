# Folders（文件夹）

状态：部分证实（静态证据；未运行验证）。

## 结论
REA 确认 New Folder… → newList:，及全部展开/折叠；补充文本明确“Share a folder via context menu”和固定区插入文件夹。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 959 | New Folder… | 'N' | 1048576 | newList: |
| 134 | Collapse All Folders | '' | None | collapseAllFolders: |
| 164 | Expand All Folders | '' | None | expandAllFolders: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3d05cd0

> Action to pin this tab to a folder

### 0x3d57160

> Share a folder via context menu

### 0x3d139d0

> Your Display Name is publicly visible when you share items like your Membership Card, Boosts, Folders or Spaces.

### 0x3d31790

> Assertion failure: Failed to insert folder in pinned section

## 未验证 / 限制
拖拽行为没有实测；分享文本不证明当前服务端仍可用，也没有生成或公开分享链接。

完整摘录：[06-folders.json](06-folders.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
