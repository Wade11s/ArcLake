# Command Bar（命令栏）

状态：部分证实（静态证据；未运行验证）。

## 结论
REA 归档将 Open Command Bar → toggleOpenOmnibox: 绑定 ⌘L，将 New Tab… → newWindowForTab: 绑定 ⌘T。补充引导文案明确“press ⌘T to open the Command Bar”，所以这不是否定 ⌘T，而是两个不同入口。文案还列出搜索网页、访问最近标签、启动扩展，及创建文件夹/固定/路由动作候选。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 240 | Open Command Bar | 'l' | 1048576 | toggleOpenOmnibox: |
| 830 | New Tab… | 't' | 1048576 | newWindowForTab: |
| 181 | Pin/Unpin Tab | 'd' | 1048576 | toggleSelectedItemsPinned: |
| 890 | Copy URL | 'C' | 1048576 | copyCurrentURL: |
| 1009 | Preferences… | ',' | 1048576 | showPreferences: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3c45f90

> Click New Tab or press ⌘T to open the Command Bar and create your very first tab in Arc.

### 0x3d15bb0

> Opens the Command Bar to search the web, navigate to recent tabs, launch an extension, and more.

### 0x3d04fc0

> Action to open Air Traffic Control routes.

### 0x3d05ab0

> Action to move this tab to a pinned section of a space.

### 0x3d20830

> Command Bar suggestion title for creating a new folder with items.

## 未验证 / 限制
搜索历史的实际数据源、动作分发、Space 切换候选与排序没有反编译或运行证据。不能仅凭主菜单含某动作，就断言该动作必然可由命令栏执行。

完整摘录：[11-command-bar.json](11-command-bar.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
