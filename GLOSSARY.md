# ArcLake 浏览器领域词汇

ArcLake 是仅面向 macOS 的 Arc 风格浏览器。本词汇表统一产品概念，不声称这些定义等同于 Arc 的内部实现。

## Language

**Profile（浏览配置）**：网站数据、浏览历史与收藏所归属的浏览身份；一个 Profile 可以供多个 Space 使用。
_Avoid_：账号、Space、登录用户

**Space（空间）**：属于一个 Profile 的浏览组织区域，拥有名称、主题、固定区和 Today 区。
_Avoid_：Profile、窗口

**Tab（标签）**：一个可导航的网页对象；可被展示、休眠或存入归档，不等同于侧边栏中的行。
_Avoid_：收藏、页面快照

**SidebarItem（侧栏项目）**：侧边栏组织树中的对象，可表示单个标签、文件夹或分屏组合。
_Avoid_：Tab（当指文件夹或分屏组合时）

**Favorite（收藏项）**：属于 Profile 的持久侧栏项目，在使用该 Profile 的各个 Space 中共享。
_Avoid_：Pinned Tab、全局收藏

**Pinned Item（固定项）**：属于某个 Space 固定区的侧栏项目，不参加 Today 自动归档。
_Avoid_：Favorite、正在运行的网页

**Today Item（临时项）**：属于某个 Space Today 区、可按闲置时间自动归档的侧栏项目。
_Avoid_：当天创建的标签

**Folder（文件夹）**：固定区中用于组织其他侧栏项目的容器。
_Avoid_：操作系统目录、Space

**Split Group（分屏组合）**：作为一个侧栏项目组织的多个网页面板，拥有方向、尺寸比例和焦点面板。
_Avoid_：多个独立窗口

**Archive Entry（归档条目）**：从活动工作区移出的项目记录，可用于恢复网页地址及组织结构，不等同于网页内容备份。
_Avoid_：History Visit、网页缓存

**History Visit（历史访问）**：某个 Profile 下的一次顶层网页访问记录；删除活动标签不等于删除访问历史。
_Avoid_：归档条目

**Little Window（小窗口）**：承载一个网页的独立轻量浏览窗口，可将网页移入指定 Space。
_Avoid_：Peek、无痕窗口

**Route（链接路由）**：对新打开链接进行匹配并选择目标 Space 或小窗口的规则。
_Avoid_：HTTP 重定向

**Command Bar（命令栏）**：统一呈现网址、搜索、标签、历史及应用命令候选的输入界面。
_Avoid_：只读地址栏、终端
