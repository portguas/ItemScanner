# Melos 使用手册（本仓库版）

> 结合官方文档（https://melos.invertase.dev/~melos-latest）与本仓库配置，覆盖安装、工作流、过滤执行、版本管理和常见排障。全程默认使用 FVM。

## 1. 环境与安装
- 确保 FVM 可用：在仓库根执行 `fvm install` / `fvm use`，生成 `.fvm/flutter_sdk`。
- Melos 安装：`fvm dart pub global activate melos`（或全局 pub activate）。本仓库的 `melos.yaml` 已设置 `sdkPath: .fvm/flutter_sdk`，所有命令会自动用 FVM SDK。
- 校验：`fvm flutter --version`、`melos --version`。

### 1.1 推荐 alias（可选）
为了避免全局 Dart 版本/路径问题，推荐在 `~/.zshrc` 加一个 alias（或直接 source 本仓库提供的文件）：
```bash
# 方式 A：直接 alias
alias melos='fvm dart run melos'

# 方式 B：使用仓库内预置 alias（按需改成你的本机路径）
[[ -f "$HOME/personal/flutter/fcmp/tool/aliases.zsh" ]] && source "$HOME/personal/flutter/fcmp/tool/aliases.zsh"
```

另外仓库也提供了 wrapper 脚本：`tool/melos`，在仓库任意子目录都能用：
```bash
./tool/melos run test
```

### 1.2 Windows（PowerShell）alias（可选）
PowerShell 的 `Set-Alias` 无法像 bash/zsh 那样天然透传参数，所以推荐用函数封装。仓库已提供 `tool\\aliases.ps1`：

临时启用（当前 PowerShell 窗口）：
```powershell
# 在仓库根目录
. .\tool\aliases.ps1
melos --version
melos run test
```

写入 Profile（永久生效）：
```powershell
notepad $PROFILE

# 追加（把路径改成你本机的仓库路径）
$repo = "$HOME\\personal\\flutter\\fcmp"
$aliases = Join-Path $repo 'tool\\aliases.ps1'
if (Test-Path $aliases) { . $aliases }
```

另外也提供了 wrapper 脚本：`tool\\melos.ps1`：
```powershell
.\tool\melos.ps1 run test
```

## 2. 工作区与约定
- workspace 范围：`packages/*`、`example/`。
- 典型包：`logging_util`、`kv_storage`、`service_network`、`db_storage`、`ui_design_system`。
- 示例：`example/` 用于集成验证。
- 忽略与生成物：`build/`、`.dart_tool/` 已在 `.gitignore`，`.fvm/` 需要保留。

## 3. 核心命令速查
| 目的 | 命令 | 说明 |
| --- | --- | --- |
| 初始化依赖 | `melos bootstrap` | 为所有包执行 `flutter pub get`（使用 `melos.yaml` 的 `sdkPath` 指向的 FVM SDK），链接本地路径依赖 |
| 静态检查 | `melos run analyze` | 等价 `melos exec -- "dart analyze ."` |
| 运行测试 | `melos run test` | 仅在有 `test/` 的包执行 `flutter test` |
| 版本管理 | `melos version` | 基于 Conventional Commit 生成版本与 changelog（需按需配置） |
| 查看包列表 | `melos list` | 按 scope/过滤展示符合条件的包 |
| 清理 | `melos clean` | 清理工作区内的构建缓存与 .dart_tool |

> 提示：`melos run <script> -- --flag` 可在脚本后透传自定义参数。

## 4. 过滤与选择性执行
官方常用过滤参数（可用于 `melos exec` / `melos bootstrap` / `melos list` / `melos clean` / `melos version` 等）：
- `--scope="<glob>"`：仅匹配包名（支持通配符）。
- `--ignore="<glob>"`：排除包。
- `--dir-exists="path"`：仅在包含指定路径/文件的包中执行（本仓库 test 脚本用此过滤）。
- `--since <ref>`：仅在指定 Git 变更后的受影响包执行。
- `--fail-fast`：任一包失败立即停止。
示例：
```bash
melos exec --scope="service_*" -- "dart analyze ."
melos run test -- --reporter=compact  # 把参数透传给 flutter test
```

## 5. 脚本（melos run）
在 `melos.yaml` 中定义：
```yaml
scripts:
  analyze:
    run: melos exec -- "dart analyze ."
  test:
    run: melos exec --dir-exists="test" -- "flutter test"
  version:
    run: melos version
```
执行方式：`melos run analyze` / `melos run test`。可结合过滤参数：
```bash
# melos v6 的 `run` 不支持 `--scope`；请用 `melos exec --scope=...`：
melos exec --scope="service_network" --dir-exists="test" -- "flutter test"

# 或者用环境变量把 `melos run` 限定到指定包（支持逗号分隔多个包名）：
MELOS_PACKAGES=service_network melos run test --no-select
```

## 6. melos exec
- 用于在多包中并行/串行执行命令，支持过滤。
- 默认并行，可加 `--no-parallel` 串行执行。
- 示例：`melos exec --scope="db_storage" -- "flutter test"`。

## 7. bootstrap 细节
- 作用：安装依赖并建立本地路径链接。
- 结合 FVM：本仓库使用 `sdkPath` 指向 `.fvm/flutter_sdk`，无需额外指定。
- 常用选项：`--no-private`（忽略 private 包），`--scope/--ignore`（仅部分包）。

## 8. version（可选）
- 基于 Conventional Commit 生成各包版本与 changelog。
- 可配置 `melos.yaml` 的 `packages`、`releaseUrl`、`tagPrefix` 等；如未配置则按默认行为。
- 典型流程：`melos version` → 检查生成的 changelog / pubspec 版本 → 提交。

## 9. 常见工作流
1. 新 clone / 切分支：`fvm install`（如需）→ `melos bootstrap`。
2. 开发阶段：`melos run analyze` → `melos run test`。
3. 新增包：创建于 `packages/`，补充 `pubspec.yaml`，再 `melos bootstrap`。
4. 示例调试：`cd example && fvm flutter run -d chrome`。

## 10. 排障与技巧
- **找不到 flutter**：确认 `fvm install` 已执行；`melos.yaml` 已含 `sdkPath`；手动测试 `fvm flutter --version`。
- **SDK 缓存权限**：如提示 lockfile 无权限，修复缓存目录权限后重试 `melos bootstrap`。
- **依赖异常/未生效**：尝试 `melos clean` → `melos bootstrap`。
- **仅测改动包**：`melos exec --since origin/main -- "flutter test"`。
- **透传参数**：`melos run test -- --coverage`。
- **私有包跳过**：可在包 pubspec `publish_to: none`，并在需要时用 `--no-private`。

## 11. 参考链接
- 官方文档入口：https://melos.invertase.dev/~melos-latest
  - CLI 参考：https://melos.invertase.dev/~melos-latest/commands
  - 过滤/执行策略：https://melos.invertase.dev/~melos-latest/commands/exec
  - Bootstrap：https://melos.invertase.dev/~melos-latest/commands/bootstrap
  - Run 脚本：https://melos.invertase.dev/~melos-latest/commands/run
  - Version：https://melos.invertase.dev/~melos-latest/commands/version
- 本仓库 `melos.yaml`：工作区 `packages/*`、`example/`，脚本 `analyze` / `test` / `version`，`sdkPath: .fvm/flutter_sdk`。
