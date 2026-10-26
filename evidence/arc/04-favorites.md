# Favorites（收藏）

状态：部分证实（静态证据；未运行验证）。

## 结论
补充文本明确 Favorites 位于顶部，且更换 Profile 会看到不同 Favorites；存在移动 Favorite(s) 到其他 Profile 的菜单描述。

## REA 菜单归档证据
本项未取得独立 REA 功能证据；下列为补充的二进制文本观察，不能冒称 REA 输出。

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3d02e30

> Drag to add Favorites

### 0x3d02dc0

> Favorites keep your most used sites and apps close

### 0x3d15730

> starting with your Favorites at the top.

### 0x3cd8830

> Each Profile has different browser data, so you might get logged out of some websites, see different Favorites up top, or need to re-install extensions.

### 0x3d57340

> Submenu to chose which profile to move Favorite(s) to.

## 未验证 / 限制
Profile 关联有明确文本支持；“同 Profile 的所有 Spaces 都共享相同 Favorites”尚缺直接共享状态证据。图标尺寸、区域位置没有截图。该项没有独立 REA 行为证据。

完整摘录：[04-favorites.json](04-favorites.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
