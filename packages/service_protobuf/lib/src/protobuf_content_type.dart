/// Protobuf 在 HTTP 等场景常用的 Content-Type。
///
/// 说明：
/// - 本包不依赖任何具体网络库（Dio/HttpClient/Socket 等）。
/// - 这里仅提供字符串常量与便捷 header map，方便上层网络层复用。
class ProtobufContentType {
  ProtobufContentType._();

  /// 常见约定：x-protobuf。
  static const String xProtobuf = 'application/x-protobuf';

  /// 另一个常见约定：protobuf。
  static const String protobuf = 'application/protobuf';

  /// gRPC 相关：grpc+proto。
  static const String grpcProto = 'application/grpc+proto';

  /// 生成适用于 HTTP 的 header（Content-Type + Accept）。
  static Map<String, String> headers({
    String contentType = xProtobuf,
    Map<String, String>? extra,
  }) {
    return <String, String>{
      'Content-Type': contentType,
      'Accept': contentType,
      ...?extra,
    };
  }
}

