# Profiles（配置文件）

状态：部分证实（静态证据；未运行验证）。

## 结论
REA 的 Change Profile 明确连到 changeProfileForCurrentSpace:。应用内说明明确列出 history、logins、cookies、extensions，并说一个 Profile 可供一个或多个 Spaces 使用。

## REA 菜单归档证据
Evidence ID: `ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。

| 对象 | 菜单标题 | key | modifier mask | selector |
|---|---|---|---|---|
| 84 | Change Profile | '' | None | changeProfileForCurrentSpace: |
| 393 | New Profile | '' | None | newProfile: |

## 补充：发行二进制中的原文
来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。

### 0x3d13ec0

> Profiles help keep your data separate across Spaces — like history, logins, cookies, and extensions. You can use any Profile across one or more Spaces. 

### 0x3cd84f0

> Profiles make your Spaces truly separate — with their own history, saved passwords, extensions, and other browsing data. No more flipping between work and personal accounts!
> 
> What do you want to call this Profile?

### 0x3cd8660

> These Spaces will start fresh in your brand new Profile — so you’ll have to log back in to websites, re-save your passwords, add extensions, etc. You can always switch back to your previous Profile though if you forgot something!

### 0x3cd8790

> Which Spaces should use this Profile?

## 未验证 / 限制
这是发行包中明确的产品语义，不是 Cookie/历史数据库隔离的实测；未创建账号或读取个人 Profile 数据。不同 Space 若使用同一 Profile，不能据此声称隔离。

完整摘录：[03-profiles.json](03-profiles.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。
