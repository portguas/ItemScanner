import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/protobuf.dart';
import 'package:service_protobuf/service_protobuf.dart';

class TestMessage extends GeneratedMessage {
  factory TestMessage({
    String? text,
  }) {
    final result = create();
    if (text != null) {
      result.text = text;
    }
    return result;
  }

  TestMessage._() : super();

  factory TestMessage.fromBuffer(
    List<int> i, [
    ExtensionRegistry r = ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final BuilderInfo _i = BuilderInfo(
    'TestMessage',
    createEmptyInstance: create,
  )
    ..aOS(1, 'text')
    ..hasRequiredFields = false;

  @override
  BuilderInfo get info_ => _i;

  @override
  TestMessage createEmptyInstance() => create();

  static PbList<TestMessage> createRepeated() => PbList<TestMessage>();

  static TestMessage create() => TestMessage._();

  static TestMessage? _defaultInstance;

  static TestMessage getDefault() =>
      _defaultInstance ??= GeneratedMessage.$_defaultFor<TestMessage>(create);

  @override
  TestMessage clone() => TestMessage()..mergeFromMessage(this);

  String get text => $_getSZ(0);

  set text(String v) => $_setString(0, v);

  bool hasText() => $_has(0);

  void clearText() => clearField(1);
}

void main() {
  group('ProtobufCodec', () {
    test('encode/decode 能正常往返', () {
      const codec = ProtobufCodec();
      final bytes = codec.encode(TestMessage(text: 'hello'));
      final decoded = codec.decode(
        bytes,
        decoder: TestMessage.fromBuffer,
      );
      expect(decoded.text, 'hello');
    });

    test('decode 支持 Uint8List', () {
      const codec = ProtobufCodec();
      final bytes = codec.encode(TestMessage(text: 'hi'));
      final decoded = codec.decode(
        Uint8List.fromList(bytes),
        decoder: TestMessage.fromBuffer,
      );
      expect(decoded.text, 'hi');
    });
  });

  group('ProtobufContentType', () {
    test('headers 提供 Content-Type 与 Accept，允许附加 header', () {
      final headers = ProtobufContentType.headers(
        contentType: ProtobufContentType.protobuf,
        extra: {'x-foo': 'bar'},
      );
      expect(headers['Content-Type'], ProtobufContentType.protobuf);
      expect(headers['Accept'], ProtobufContentType.protobuf);
      expect(headers['x-foo'], 'bar');
    });
  });

  group('ProtobufFraming', () {
    test('encodeLengthPrefixed 4 字节大端', () {
      const framing = ProtobufFraming();
      final bytes = framing.encodeLengthPrefixed([1, 2, 3]);
      expect(bytes.length, 7);
      expect(bytes.sublist(0, 4), [0, 0, 0, 3]);
      expect(bytes.sublist(4), [1, 2, 3]);
    });

    test('LengthPrefixedDecoder 支持分段流式解包', () {
      const framing = ProtobufFraming();
      final decoder = LengthPrefixedDecoder();

      final packet1 = framing.encodeLengthPrefixed([1, 2, 3]);
      final packet2 = framing.encodeLengthPrefixed([4, 5]);

      final chunk = [
        ...packet1.sublist(0, 5),
      ];
      final out1 = decoder.addChunk(chunk);
      expect(out1, isEmpty);

      final out2 = decoder.addChunk([
        ...packet1.sublist(5),
        ...packet2,
      ]);
      expect(out2.length, 2);
      expect(out2[0], [1, 2, 3]);
      expect(out2[1], [4, 5]);
    });
  });
}
