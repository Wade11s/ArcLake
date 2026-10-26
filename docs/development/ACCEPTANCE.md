# 验收场景与测试方案

以下均为待执行验收，不是已通过的测试报告。所有数据使用独立测试 bundle ID/store UUID；不读取、改写或清除用户 Arc 数据。P0：数据/安全/核心功能，发布阻塞；P1：体验与非关键路径，发布前必须通过或明确降级。

## 1. 测试层与环境

- Core tests：直接测试 Workspace Interface 与纯 Routing/Archive policy；固定 Clock、UUID source；不能靠等待真实 12 小时。
- Storage integration：临时真实 SQLite，包含事务回滚、迁移、重启、WAL 与错误注入；内存 adapter 不能替代。
- WebKit integration：真实 WKWebView + 独立具名 stores + 本地 HTTP(S) fixtures。HTTP localhost 用于受控本地验证，TLS 负例另用不可信测试证书，绝不能为通过测试关闭生产验证。
- App UI：XCTest/XCUITest 或具备用户授权的 GUI 工具；fixture 参数启动应用，事件从真实菜单/键盘/拖拽进入。
- 测试服务器是独立开发进程；两个不同 origin、持久 Cookie、localStorage、IndexedDB、重定向、POST、下载、弹窗、beforeunload、进程失效页面。
- 日志使用随机测试 token；避免真实网站登录。录屏/截图仅对测试窗口，导出前检查隐私。
- 每次记录系统版本、硬件、构建号、数据库 schema 与 WebKit store UUID。覆盖最低 macOS 14 和当前系统；只有当前系统通过不能替代最低系统承诺。

## 2. 场景清单

| ID | 等级/功能 | Given / When | Then（明确通过条件） |
|---|---|---|---|
| T01 | P0 F03 | A1/A2 共用 Profile A，B1 用 B；同 origin 写不同 Cookie/localStorage/IndexedDB | A1/A2 相互可见 A 数据；B 保持 B；无应用侧 Cookie 复制 |
| T02 | P0 F03 | 写入持久 Cookie/本地存储，正常退出重启；再模拟强制退出 | Profile store UUID 不变；持久数据仍按 Profile 隔离；强退只允许丢未提交的非结构更新 |
| T03 | P0 F01 | 网页有 load counter、输入内容；切换 Sidebar/主题各 50 次 | WKWebView 身份不变，load counter 不增加，输入不丢 |
| T04 | P0 F10 | 同 Profile 小窗表单/JS 计数器/滚动位置；移入主窗 | 单实例 detach/attach 后内容保持；小窗关闭，owner 恰好一个，焦点能输入 |
| T05 | P0 F03 | 跨 Profile 普通拖拽，再显式“复制链接” | 拖拽拒绝且原树不变；显式复制生成新 ID/目标 store，只复制 URL/标题，原页保留 |
| T06 | P0 F02 | 全新空数据库首次启动 | 恰好一个 Default Profile 与 Space，roots 完整，store UUID 已持久化后才加载网页 |
| T07 | P0 F02 | 不同 Space 各有 Today/Pinned；切换图标与 Control+数字 | 区域独立、最近选择可恢复；Favorites 随 Profile 而非 Space 变化 |
| T08 | P0 F04 | A 的两个 Space；将 Today Tab 加收藏，再重排和取消收藏 | 同 Profile 立即显示同一记录/顺序；B 不可见；取消收藏进入当前 A Space Today，不产生隐性副本 |
| T09 | P0 F05 | 固定 Tab，导航离开 savedURL，重命名，⌘W 后再次选择 | 固定项保留、customTitle 不被网页 title 覆盖，再打开 savedURL；“重置”也返回 savedURL |
| T10 | P0 F06 | 三层 Folder；拖到自身、后代、Today、异 Profile Space；再合法重排 | 非法均无部分提交；合法操作保留所有叶 Tab、profile 与顺序；8 层限制可解释 |
| T11 | P0 F03 | 将含固定、Today、Split 的 Space 从 A 改到 B；注入旧页迟到 title/URL callback | 有确认；旧实例释放，新实例用 B store；旧回调被丢弃；A 历史不归到 B |
| T12 | P0 F03 | 无 Space/小窗引用的 Profile 有 Favorites/历史；触发删除并模拟 WebKit 删除失败 | pending/deleting 可见、可重试、禁止重新使用；失败不显示“全部已清除”；成功后元数据和 store 删除完成 |
| T13 | P0 F07 | 固定时钟：Today 闲置 11h59m/12h，Pinned 与 Favorite 已闲置 30d | 边界前不归档、到阈值归档 Today；Pinned/Favorite 永不自动归档 |
| T14 | P0 F07 | 页面显示 20h，再切走；另一个项正在下载、权限提示或导航 | 可见项保护；切走从最后可见时刻计时；受保护项不归档；下载结束后正常参与 |
| T15 | P0 F07 | 关闭 App 13h 后启动；选中项和后台过期项；系统时钟倒退 | 先恢复选中保护，再归档后台合格项；负时差视作零；不要求内存计时器连续运行 |
| T16 | P0 F07 | 归档 Folder/Split，删除来源 Space或给其换 Profile；恢复并双击恢复按钮 | 保留树/方向/比例，仍在原 Profile；必要时选/建 Recovered Space；fresh IDs，重复恢复幂等，不路由 |
| T17 | P0 F09 | 从两个 Tab 建 Split，添加至4；再请求第五个或跨 Profile 面板 | 4 个成功；第5个/跨 Profile 请求无状态变化并说明原因；Tab 不同时出现在原根和组 |
| T18 | P1 F09 | 横/纵切换、拖比例、切焦点、退出重启 | 比例正且和为1；焦点/方向/顺序恢复；小屏不足拒绝增面板，不裁掉不可操作控件 |
| T19 | P0 F09/F05 | 固定 Split 关闭一面板；Today Split 关闭一面板；分离全部 | 固定叶回固定根并卸载；Today 叶归档；仅1叶时折叠仍保留原区域；分离不丢数据 |
| T20 | P0 F10 | 三个不同 Profile 小窗；关闭一个；退出 App；再启动 | 手动关闭仅归档该窗；退出不逐窗归档；小窗恢复清单不自动加载全部 URL |
| T21 | P0 F11 | ⌘T 输入 URL，Escape 取消；⌘L 预填后提交；命令候选固定/切换Space | 取消不产生空 Tab；两模式目标正确；命令与菜单/快捷键的校验和结果一致 |
| T22 | P0 F11/F03 | 搜索 A 历史过程中切到 B；让 A 慢查询最后返回 | A 结果不进入 B 的 UI，即便只出现一帧也失败；B 查询只读取 B 数据 |
| T23 | P1 F11 | 10000 History/1000 Sidebar 项，多次输入同 query | 同输入排序稳定，手动高亮不跳动，最多30项；不发送网络联想；p95延迟目标按设备记录 |
| T24 | P1 F01/F11 | 中文输入法组合中按键、编辑标题；隐藏侧栏；小窗获得焦点 | 不提交半截组合文本；Escape 逐层取消；菜单命令只影响对应窗口；隐藏后可键盘恢复 |
| T25 | P0 持久化 | 在归档/恢复/移动事务提交前后模拟崩溃 | 重启只见完整前态或完整后态，无半棵树、重复归档、孤儿Tab |
| T26 | P0 持久化 | 数据库磁盘满/只读、预期revision不匹配 | 显式错误，原树/网页保留；不发布未提交状态、不静默覆盖更新 |
| T27 | P0 迁移 | 旧schema迁移；中断迁移；打开未来schema | 成功迁移可验证；失败可恢复一致性备份；未来schema只读拒绝，不初始化覆盖 |
| T28 | P0 并发 | 后台归档候选形成后立即固定/切入该Tab，再应用旧候选 | 重新检查revision和保护集合，项不被错误归档 |
| T29 | P0 生命周期 | Tab 删除/换Profile后产生旧代回调；模拟网页进程终止 | 旧事件不改新实例；终止显示失败与重载，不让整个应用崩溃 |
| T30 | P1 资源 | 连续创建/关闭100次小窗，主窗口在4面板和单页切换 | registry/token/host计数回到合理基线；同WebView无双宿主；软预算不强杀受保护页 |
| T31 | P0 F08 | 两规则同时匹配；切换顺序；精确含fragment/default port差异 | 按SPEC规范化与首命中执行；match preview和实际路径完全一致 |
| T32 | P0 F08 | 外部URL、普通当前Tab链接、redirect、Archive恢复、显式Space打开 | 仅规定来源执行路由；redirect/恢复不递归路由；明确目标优先规则 |
| T33 | P0 F08 | 目标Space删除、Profile待删除；重复同openRequestID；不同ID同URL | 无效目标跳过并告警；同ID不重复创建；不同ID按两次用户请求处理 |
| T34 | P0 安全 | 输入/导入javascript:data:file:；恶意window.open；不可信证书 | 不执行脚本/本地文件；无授权弹窗不批量开窗；证书失败不绕过 |
| T35 | P0 F06 | 清单含超深树/超量Tab/重复ID/非法URL/未知schema；正常导出再导入 | 非法整体拒绝无部分导入；正常导入生成新ID，结构可复核，网页不批量加载；无敏感Profile数据导出 |
| T36 | P1 基础浏览 | 下载/取消/失败重试；用户拒绝文件/摄像头权限；上传取消 | 不自动打开文件、不绕过权限；保护状态及时释放；取消不成为成功 |
| T37 | P0 系统入口 | 用户主动允许测试默认浏览器后，从其他App打开真实HTTP(S) | URL事件进入统一Router，落到正确Profile/Space/Little；测试结束由用户恢复原默认设置 |
| T38 | P1 无障碍 | VoiceOver与仅键盘完成切Space、归档恢复、命令执行 | 控件有可读标签/焦点顺序，状态变化可感知；隐藏UI不留下不可退出焦点陷阱 |
| T39 | P0 F07/F03 | 清空 A 的 Archive/History；推进到30天/90天保留期边界 | 只清对应范围；B 数据不变；清History不删Pinned/Favorites，清Archive不删History；到期清理可重复且不跨Profile |
| T40 | P0 F07/F09 | Today Split 中一叶刚使用、其余过期；随后全部闲置到阈值 | 前者整组保留；后者整组归档且恢复时比例/方向一致；不产生半组自动归档 |

## 3. 属性测试与故障注入

- 每次合法 command 后 I01–I12 成立；非法 command 不改变快照 revision 或数据。
- pin/unpin 往返保留 Tab identity/URL，只有区域与时间按规则改变。
- Split create/separate 往返叶集合一致，不遗漏、不复制；保存/载入模型等价。
- Archive snapshot → restore 在忽略新 ID/时间/恢复位置回退后，内容与树结构等价。
- Router 同请求、同规则快照总是同结果；禁止根据不可控网络重定向改变已选 Profile。
- 数据库提交、WebKit加载、store删除分别故障；不能把它们当作同一事务模拟出虚假的原子保证。

## 4. 验收产物

每次执行写入 `test-results/m0/<时间戳>/`（M0 已按此落盘，见 [M0 实测报告](M0-RESULTS.md)）：环境信息、稳定清单、F/T 对照、通过/失败/跳过及原因、可复现步骤、脱敏日志与截图路径。失败记录保留原样，不得事后覆盖成通过。

最低验收报告必须能回答：数据是否持久；隔离是否真实；输入是否安全；哪些能力是降级；所有可点击入口是否执行同一规则。只有截图相似、函数存在或编译通过都不能算完成这些验收。
