# item_scanner

基于 Flutter 的通用组件与基础能力 Monorepo（Melos 管理）。提供网络、存储、日志与设计系统等可复用包，并在 `example/` 中给出集成示例。

## 目录结构
- `packages/`：可复用包
- `example/`：集成示例应用
- `tool/`：工具脚本
- `melos.yaml`：Melos 配置
- `pubspec.yaml`：工作区根配置

## 包列表
| 包名 | 说明 |
| --- | --- |
| `db_storage` | 数据库访问封装，默认使用 SQLite，可通过适配器替换 |
| `kv_storage` | 轻量 KV 存储封装，默认使用 Hive，可替换适配器实现 |
| `logging_util` | 通用日志封装，支持环境过滤、文件写入与错误上报 |
| `service_network` | 基于 Dio 的网络封装 |
| `service_protobuf` | Protobuf 编解码与装包/拆包工具 |
| `ui_design_system` | 设计系统与基础 UI 组件 |

## 环境要求
- 使用 FVM 管理 Flutter 版本：进入仓库后先执行 `fvm use`（或 `fvm install`）
- Dart SDK `>=3.0.0 <4.0.0`

## 快速开始
1. 绑定 Flutter 版本：`fvm use`（或 `fvm install`）
2. 安装 Melos（若未全局安装）：`fvm dart pub global activate melos`
3. 初始化依赖并链接本地包：`melos bootstrap`

## 常用命令
- `fvm flutter --version`：确认 Flutter 版本
- `melos run analyze`：静态检查
- `melos run test`：运行测试
- `fvm dart format .`：格式化代码
- `fvm flutter run`：运行示例（在 `example/` 下执行，可加 `-d chrome`）
- `melos run build:android` / `melos run build:android:aab` / `melos run build:ios` / `melos run build:web`：构建示例应用

## 技术约定
- 状态管理：`provider`
- 网络层：`dio`
- 代码风格：2 空格缩进，文件 UTF-8，避免手工对齐空格
- 生成产物：`.dart_tool/` 与 `build/` 不提交

## 发布
- `melos version`：生成各包版本号与 changelog（语义化版本）
