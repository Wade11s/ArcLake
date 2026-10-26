# M2 Foundation Demo 实施结果

日期：2026-10-27。状态：**M2 Gate 通过。**

环境：Apple Silicon arm64；macOS 27.0.1；Xcode 27.0 / Swift 6.4；Swift tools 6.4；Mach-O 最低部署目标 macOS 27.0。

主报告：[latest.json](../../test-results/m2/latest.json)。最近一次完整证据为 `test-results/m2/20261027T004227-27a4b161/`，包含[UI 启动截图](../../test-results/m2/20261027T004227-27a4b161/ui-ready.png)。

## 1. 已交付

- 产品 Browsing 层：真实 WKWebView、稳定 TabID 注册表、具名 Profile store、前进/后退/刷新、导航开始/提交/完成/失败、进程终止、JS 弹窗和 target=_blank 入口。
- SwiftUI Foundation Demo：可调 Sidebar、Favorites/Pinned/Today 树、Folder、Space 切换、地址入口、浏览器工具栏、加载/失败/重试和空状态。
- 命令栏：URL、搜索、当前 Profile 历史、活动 Tag、Space 和应用命令；`⌘T` 与 `⌘L` 共用同一候选引擎和命令 registry。
- 快捷键：`⌘S`、`⌘L`、`⌘T`、`⌘W`、`⌘D` 与 Control+1…9；`javascript:`、`data:`、`file:` 不进入导航候选。
- Space：创建、名称/图标/主题编辑、前后排序、Control+1…9 切换、Profile 更换确认。
- Profile：创建、切换、无 Space 时删除、deleting/pending 可见状态、WebKit store 删除失败后的 Retry。
- Favorites（多个单 Tab 收藏与重排）、Pin/Unpin、savedURL 重置、Folder 新建/重命名、Sidebar 拖拽和上下文菜单。
- 跨 Profile 复制：新 Tab/Item ID、目标 Profile store，不复制表单、历史或 Cookie。
- 冷启动：恢复到选中 Tab 与当前 Space，SQLite 元数据和 Profile store UUID 保持不变。

## 2. 验证结果

- **53/53 Swift 测试通过**：M0 回归 5、M1/M2 Core 36、Persistence 9、真实 WKWebView Browsing 3。
- 13 个具名 M2 场景全部通过：T01、T03、T05–T12、T21 两条路径和真实页面导航失败。
- 真实 WebKit 集成覆盖：加载、标题、URL、后退、连接失败、target=_blank、T03 实例复用、Cookie/localStorage Profile 隔离。
- UI + 真实页面烟测：
  - 首次启动创建 1 Profile、1 Space、1 Tab，真实打开 loopback 页面并写入 History。
  - 使用同一 SQLite 第二次启动仍为 1 Profile、1 Space、1 Tab，没有重复 bootstrap。
  - schema 1、WAL、revision 持久化正常。

## 3. 门禁映射

| 场景 | 结果 |
|---|---|
| T01 Profile 隔离 | 产品 store 的 Cookie 与 localStorage 实测隔离 |
| T02 重启恢复 | M0 强退/重启 + M2 同数据库双启动烟测 |
| T03 实例稳定 | 同一 identity/Space 更新不重建 WKWebView，页面 JS 状态保持 |
| T04 Little Window | M0 已完成主窗/小窗单实例移交；M2 不提供正式 Little UI |
| T05 跨 Profile | 普通移动被拒；显式复制生成新 ID、目标 store，原页保留 |
| T06 首次启动 | Default Profile/Space 事务提交后才进入 Ready |
| T07–T10 组织 | Space、Favorites、Pinned、Folder 和随机树属性测试通过 |
| T11 更换 Profile | release 旧 identity、目标 store 重建、旧回调丢弃、A History 保留 |
| T12 Profile 删除 | pending/retry/deleting 可见，失败不标记成功，Retry 后元数据删除 |
| T21 命令栏 | New Tab / Navigate Current 目标正确；URL/搜索/历史/命令候选来源受限 |

## 4. 明确边界

- M2 是 Foundation Demo，不包含 M3 的自动归档/Library、M4 的正式 Split/Little Window 或 M5 的路由/完整下载管理。
- T04 的 Little Window 证据仍来自 M0；M2 的产品 UI 未提前实现 M4 小窗管理。
- Profile 只有在没有 Space 时才可删除；Space 删除与归档语义留给 M3，UI 会明确阻止而非伪造成功。
- target=_blank 当前创建同 Profile 新 Tab；完整路由和目标选择属于 M5。
- 页面失败和重试已实现；DRM、扩展、密码填充和全部 Safari 站点能力不在承诺范围。

## 5. 复现

```bash
python3 scripts/run_m2.py
```

脚本会构建 `ArcLakeM2`、运行全部测试、启动动态端口 loopback fixture，并使用临时 SQLite/随机 WebKit stores 完成两次 UI 启动烟测。不会读取用户 Arc 数据或更改默认浏览器。
