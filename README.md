# ArcLake

仅面向 macOS 的 Arc 风格浏览器独立实现。当前已完成 **M0 浏览器能力验证** 与 **M1 Workspace 基础**；交付仍是开发基线，不是可日用浏览器。

- [开发文档与复现方案](docs/development/README.md)
- [M0 运行结果、问题与剩余门槛](docs/development/M0-RESULTS.md)
- [M1 领域模型、SQLite 与启动恢复结果](docs/development/M1-RESULTS.md)
- [Arc 原始分析证据](evidence/arc/no-hopper/README.md)

## 运行验证

需要 macOS 27.0 或更高、Xcode 27 / Swift 6.4 工具链和 Python 3；没有第三方包依赖。最低系统基线为 macOS 27.0，开发和 M0 验证环境为 arm64 macOS 27.0.1。

SwiftUI、AppKit、WebKit、Foundation 和 SQLite 均使用当前 macOS 27 SDK 的系统版本。项目不保留旧系统兼容分支，也不引入替代 Apple 框架的第三方包。

```bash
# 构建、单元测试、真实 WebKit 集成测试与清理
python3 scripts/run_m0.py --test

# 最低系统模式：当前系统必须满足 macOS 27
python3 scripts/run_m0.py --test --require-minimum-os

# 可见的本地演示窗口（退出 App 后结束服务器并清理此次测试数据）
python3 scripts/run_m0.py --demo

# M1：构建、40 项测试、两次 SwiftUI 冷启动烟测
python3 scripts/run_m1.py

# 只运行 Workspace SQLite 骨架
swift run ArcLakeM1
```

应用位于 `build/ArcLakeM0.app`，请通过上述脚本启动，因为测试端口和 store UUID 由脚本提供；直接双击缺少参数时会退出。自动化模式会短暂显示并激活自己的测试窗口，以验证真实滚动、AppKit 键盘输入和窗口移交。强退测试只杀死脚本创建的测试 App；内容进程测试只对经 `ps` 校验为 `WebKit.WebContent` 的本轮 PID 发送 `SIGKILL`。

演示：A1/A2 属于 Profile A，B1 属于 B。在页面中写入/读取测试 marker，观察同 Profile 共享、跨 Profile 隔离；填写 draft 后点击 Little window，再在主窗点击 Return page。M0 仅支持一个实验小窗和探针级原生弹窗/下载，不含完整标签、历史、下载管理器或命令栏。

**不要在 M0 中使用真实账号或重要数据。** 每轮使用新建的具名存储，脚本结束会删除该轮存储；不会读取/删除 Arc 数据，也不会修改默认浏览器。正常重启和强退持久性在同一轮的独立进程之间验证，不代表不同 demo 轮次保留数据。

## 项目布局

- `Sources/M0Core/`：测试配置、Profile/Space 与事件身份约束。
- `Sources/ArcLakeM0/`：SwiftUI 壳、AppKit 窗口、稳定 WKWebView 运行实例、自动化探针。
- `Sources/ArcLakeCore/`：强类型领域模型、I01–I12、Workspace 命令、BrowserEvent、AppController。
- `Sources/ArcLakePersistence/`：系统 SQLite schema v1、迁移、事务与历史查询。
- `Sources/ArcLakeM1/`：Loading/Ready/Recovery 三态 SwiftUI 启动骨架。
- `Tests/`：M0 回归、M1 Core 与 Persistence 测试。
- `Fixtures/M0/`、`scripts/m0_fixture.py`：两个仅 loopback 的测试 origin。
- `Packaging/`：独立 bundle ID、App Sandbox 与 network.client 权限；临时 ad-hoc 签名，未公证。
- `test-results/m0/`：逐轮环境、稳定 UUID 清单、JSON 结果和日志。`latest.json` 指向最近一轮。

可以单独运行：
```bash
swift test
python3 -m unittest discover -s scripts -p 'test_m0_fixture.py'
bash scripts/build_m0.sh
```

若清理失败，保留清单并重试（只允许本项目 M0 清单）：
```bash
python3 scripts/cleanup_m0.py test-results/m0/<run>/run-config.json
```

macOS 27 最低系统基线上的 M0 与 M1 Gate 均已通过。M1 不加载真实网页，也不是完整 11 项功能；下一阶段为 M2 Foundation Demo。
