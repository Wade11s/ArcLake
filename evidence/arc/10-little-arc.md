# Little Arc（小窗口）

状态：部分证实（静态证据；未运行验证）。

## 结论
REA 确认 New Little Arc Window → newLittleBrowserWindow:（⌘⌥N）；Open Little Arc or Peek in… → openInCurrentSpace:（⌘O）。补充设置文本明确其他应用链接在 Little Arc 打开，并有关闭全部 Little Arc 窗口操作描述。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 463 | New Little Arc Window | 'n' | 1572864 | newLittleBrowserWindow: |
| 1495 | Open Little Arc or Peek in… | 'o' | 1048576 | openInCurrentSpace: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3d13170

> Links from other apps open in Little Arc

### 0x3c558f0

> Close Little Arc Windows

### 0x3c55910

> Closes all open Little Arc windows

### 0x3d167e0

> Presents the Little Arc “Open In” Menu

### 0x3d232b0

> Title for button in Little Arc toolbar that reveals more 'Open In' destinations

## 未验证 / 限制
浮动层级、轻量性能和不打扰主窗口没有运行证据。没有将 Peek 和 Little Arc 混为同一实现。

完整摘录：[10-little-arc.json](10-little-arc.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
