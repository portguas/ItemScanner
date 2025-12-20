#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROTO_DIR="${PROTO_DIR:-$ROOT/protos}"
OUT_DIR="${OUT_DIR:-$ROOT/lib/src/gen}"
PROTOC="${PROTOC:-protoc}"
PLUGIN="${PROTOC_GEN_DART:-$(command -v protoc-gen-dart || true)}"

if [[ -z "$PLUGIN" ]]; then
  cat >&2 <<'EOF'
缺少 protoc-gen-dart，先安装：
  fvm dart pub global activate protoc_plugin
或指定环境变量 PROTOC_GEN_DART 指向插件可执行文件。
EOF
  exit 1
fi

if [[ ! -d "$PROTO_DIR" ]]; then
  echo "未找到 proto 目录：$PROTO_DIR" >&2
  exit 1
fi

mapfile -t files < <(find "$PROTO_DIR" -name '*.proto' | sort)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "在 $PROTO_DIR 下未找到 .proto 文件"
  exit 0
fi

mkdir -p "$OUT_DIR"

"$PROTOC" \
  --plugin=protoc-gen-dart="$PLUGIN" \
  --dart_out=grpc:"$OUT_DIR" \
  -I "$PROTO_DIR" \
  "${files[@]}"

echo "生成完成：$OUT_DIR"
