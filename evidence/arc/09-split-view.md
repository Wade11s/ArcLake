# Split View（分屏）

状态：部分证实（静态证据；未运行验证）。

## 结论
REA 确认新增、关闭当前分屏、最大化当前分屏、从分屏分离页面的动作连接。补充文本明确水平/垂直转换；“跳到第四个 Split View 页面”支持第四面板设计，另有超过最大面板数和调整大小事件标识。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 194 | Add Split View | '=' | 393216 | addSplitPanel: |
| 228 | Close this Split Pane | '-' | 393216 | closeFocusedSplitViewPanel: |
| 629 | Expand Current Split | '' | None | maximizeCurrentSplitViewPane: |
| 1300 | Separate Page from Split View | '' | None | separateTabFromSplitView: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3d05170

> Convert to Horizontal Split View

### 0x3d051e0

> Convert to Vertical Split View

### 0x3d05230

> Add Vertical Split View

### 0x3d16c80

> Jumps to the fourth Split View page in your current window.

### 0x41283f0

> splitViewMaximumPanesExceeded

### 0x413d200

> onDidEndWindowContentsSplitViewPaneResize

## 未验证 / 限制
第四面板说明不等于证明最多恰好四个；最大数值、拖动调整尺寸和把整个分屏固定成一个标签均未实测或追踪实现。

完整摘录：[09-split-view.json](09-split-view.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
