# 垂直侧边栏

状态：部分证实（静态证据；未运行验证）。

## 结论
REA 主菜单确认 Show/Hide Sidebar → toggleArcSidebar:，归档快捷键为 ⌘S；另有 Reveal Tab in Sidebar。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 33 | Show/Hide Sidebar | 's' | 1048576 | toggleArcSidebar: |
| 752 | Reveal Tab in Sidebar | '' | None | revealCurrentTabInSidebar: |
| 61 | Go Forward | ']' | 1048576 | navigateTabForward: |
| 946 | Go Back | '[' | 1048576 | navigateTabBack: |
| 1095 | Show/Hide Toolbar | 'D' | 1048576 | toggleArcToolbar: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3cdc880

> Sidebar Container

## 未验证 / 限制
左侧垂直几何布局、地址栏和导航按钮实际所在位置未截图验证。存在 Show/Hide Toolbar 菜单归档，不能把“永远没有顶部栏”作为结论。

完整摘录：[01-sidebar.json](01-sidebar.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
