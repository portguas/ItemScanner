import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

/// 从二进制 buffer 构造 PB 消息的工厂函数。
///
/// 推荐直接传生成代码自带的 `MyMessage.fromBuffer`。
typedef ProtobufDecoder<T extends GeneratedMessage> = T Function(List<int> bytes);

/// Protobuf 编解码工具。
class ProtobufCodec {
  const ProtobufCodec();

  /// 将 PB 消息编码为二进制。
  List<int> encode(GeneratedMessage message) => message.writeToBuffer();

  /// 将二进制解码为 PB 消息。
  T decode<T extends GeneratedMessage>(
    Object? data, {
    required ProtobufDecoder<T> decoder,
  }) {
    final bytes = _normalizeBytes(data);
    return decoder(bytes);
  }

  static List<int> _normalizeBytes(Object? data) {
    if (data == null) return const <int>[];

    if (data is Uint8List) return data;
    if (data is List<int>) return data;

    if (data is List) {
      return data.map((e) => e as int).toList(growable: false);
    }

    throw ArgumentError.value(
      data,
      'data',
      '期望响应为 bytes（Uint8List/List<int>），但实际是 ${data.runtimeType}',
    );
  }
}

