# service_protobuf

用于 Protobuf（PB）二进制的编解码与装包/拆包工具，独立于网络传输层（HTTP/TCP/WebSocket 等）。

## 1. 安装

在需要使用 PB 的业务包中添加依赖（本仓库内用 path 引用即可）：

```yaml
dependencies:
  service_protobuf:
    path: ../service_protobuf
```

## 2. 典型用法

### 2.1 编解码（GeneratedMessage <-> bytes）

```dart
import 'package:service_protobuf/service_protobuf.dart';

// import 'xxx.pb.dart'; // 你的生成代码

const codec = ProtobufCodec();

// 编码：GeneratedMessage -> bytes
final bytes = codec.encode(loginRequest);

// 解码：bytes -> GeneratedMessage
final resp = codec.decode(
  bytesFromServer,
  decoder: LoginResponse.fromBuffer,
);
```

### 2.2 HTTP 场景的 Content-Type（不依赖任何 HTTP 库）

```dart
final headers = ProtobufContentType.headers(
  contentType: ProtobufContentType.xProtobuf,
  extra: {'x-trace-id': '123'},
);

// 将 bytes 作为 body、headers 作为请求头，交给你自己的 HTTP 层发送即可
```

### 2.3 TCP/Socket 场景的装包/拆包（length-prefix）

很多 TCP 协议会用 “长度前缀 + PB body” 的方式做分包，推荐 4 字节大端：

```dart
import 'package:service_protobuf/service_protobuf.dart';

const framing = ProtobufFraming();
final decoder = LengthPrefixedDecoder();

// 发送：对 PB body 做 length-prefix
final packet = framing.encodeLengthPrefixed(pbBodyBytes);

// 接收：Socket 可能分段到达，逐段喂入并取出完整 body
final bodies = decoder.addChunk(chunkFromSocket);
for (final body in bodies) {
  // body 就是单条 PB 的 bytes
}
```

## 3. 生成 PB 代码（参考）

本包证明“如何发送/解析 PB”，不负责 `.proto` 的生成。

常见做法（示例）：

```bash
# 安装插件（只需一次）：
fvm dart pub global activate protoc_plugin

# 使用仓库内脚本（默认输入 protos/，输出 lib/src/gen/）
cd packages/service_protobuf
./tool/gen_proto.sh

# 自定义参数：
PROTO_DIR=../my_protos OUT_DIR=lib/src/gen ./tool/gen_proto.sh
# 如需自定义 protoc 或插件路径：
PROTOC=/usr/local/bin/protoc PROTOC_GEN_DART=$HOME/.pub-cache/bin/protoc-gen-dart ./tool/gen_proto.sh
```
