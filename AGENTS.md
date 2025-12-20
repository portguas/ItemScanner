# Repository Guidelines

## Basic
- 全部使用中文回答

## Project Structure & Module Organization
- Monorepo 由 Melos 管理，核心包位于 `packages/`：`core_utils`（基础工具/扩展）、`service_network`（基于 Dio 的网络封装）、`ui_design_system`（设计系统与基础组件）；`example/` 提供集成示例。
- 每个 package 的 `lib/` 输出可复用代码，`test/` 放单元/Widget 测试，`pubspec.yaml` 记录依赖与版本；生成产物存放于 `.dart_tool/` 或 `build/`，`build/` 目录不应提交。
- 使用 FVM 管理 Flutter 版本，进入仓库后先执行 `fvm use`（或 `fvm install`），避免版本漂移。

## Build, Test, and Development Commands
- `fvm flutter --version`：确认 FVM 绑定的 Flutter 版本。
- `melos bootstrap`：初始化/更新依赖并链接本地包（首次克隆或依赖变更后执行）；如未全局安装 melos，可用 `fvm dart pub global activate melos` 先安装。
- `melos run analyze`：在所有包内运行 `dart analyze`，保持静态检查为 0。
- `melos run test`：在存在 `test/` 的包运行 `fvm flutter test`，提交前务必通过。
- `fvm flutter run` 于 `example/`：本地手动验证组件，可指定设备 `fvm flutter run -d chrome`。
- `fvm dart format .`：提交前格式化，避免风格差异；必要时可单独格式化子包。
- `melos version`：发布时生成各包版本号与 changelog（遵循语义化版本）。

## Coding Style & Naming Conventions
- Dart 默认 2 空格缩进，文件使用 UTF-8，保留末尾换行；避免手工对齐空格。
- 类/枚举用 PascalCase，方法、变量、常量用 lowerCamelCase；文件/目录名用下划线小写（如 `network_client.dart`）。
- 导出文件建议按功能命名 `<feature>_*.dart`，Widget 组件保持单一职责；提交前确保 `melos run analyze` 无告警。

## Testing Guidelines
- 使用 `flutter_test`；工具类可写纯 Dart 测试，UI/网络使用 mock（如 Dio adapter）避免真实请求。
- 新功能至少提供一个测试，置于对应包的 `test/`，文件命名 `<feature>_test.dart`；复现缺陷先添加回归用例。
- 覆盖率需要时在包内运行 `fvm flutter test --coverage` 并收集 `coverage/lcov.info`；避免将生成报告提交仓库。

## Commit & Pull Request Guidelines
- 建议使用简短祈使句或 Conventional Commit（如 `feat: add button tokens`），首行控制在 ~72 字符，关联 Issue 用 `#<id>`。
- PR 描述需包含：变更摘要、受影响模块（列出 package）、测试结果（命令或截图），UI 变更附截图/GIF；涉及示例请同步更新 `example/lib/`。
- 提交前确保 `melos run analyze` 与 `melos run test` 通过；如包含 API 变更，请更新相应 README/文档并记录破坏性调整。

## 项目介绍
- 使用最新的dart语法写代码
- 项目是一些自封装的通用组件合集，通用组件都封装在 `packages/`里
- 状态管理使用`provider`
- 网络使用`dio`