import 'dart:typed_data';

/// TCP/流式场景的 PB 装包/拆包工具。
///
/// 典型用法：服务端/客户端用 4 字节大端 length-prefix 发送 PB 二进制。
class ProtobufFraming {
  const ProtobufFraming();

  /// 使用 4 字节大端 length-prefix 装包（总长度 = 4 + 消息长度）。
  Uint8List encodeLengthPrefixed(
    List<int> messageBytes, {
    int lengthBytes = 4,
    Endian endian = Endian.big,
  }) {
    if (lengthBytes != 4 && lengthBytes != 2) {
      throw ArgumentError.value(
        lengthBytes,
        'lengthBytes',
        '只支持 2 或 4 字节长度前缀',
      );
    }

    final length = messageBytes.length;
    if (lengthBytes == 2 && length > 0xFFFF) {
      throw ArgumentError.value(
        length,
        'messageBytes.length',
        '2 字节长度前缀不足以表示该长度',
      );
    }

    final header = ByteData(lengthBytes);
    if (lengthBytes == 4) {
      header.setUint32(0, length, endian);
    } else {
      header.setUint16(0, length, endian);
    }

    final result = Uint8List(lengthBytes + length);
    result.setRange(0, lengthBytes, header.buffer.asUint8List());
    result.setRange(lengthBytes, lengthBytes + length, messageBytes);
    return result;
  }
}

/// length-prefix 解包器，支持流式喂入。
class LengthPrefixedDecoder {
  LengthPrefixedDecoder({
    this.lengthBytes = 4,
    this.endian = Endian.big,
  }) {
    if (lengthBytes != 2 && lengthBytes != 4) {
      throw ArgumentError.value(
        lengthBytes,
        'lengthBytes',
        '只支持 2 或 4 字节长度前缀',
      );
    }
  }

  final int lengthBytes;
  final Endian endian;

  Uint8List _buffer = Uint8List(0);
  int _offset = 0;

  /// 喂入一段字节，返回已解出的完整消息列表（可能一次解出多条）。
  List<Uint8List> addChunk(List<int> chunk) {
    final messages = <Uint8List>[];
    _append(chunk);

    while (true) {
      final available = _buffer.length - _offset;
      if (available < lengthBytes) break;

      final header = ByteData.sublistView(_buffer, _offset, _offset + lengthBytes);
      final bodyLength = lengthBytes == 4
          ? header.getUint32(0, endian)
          : header.getUint16(0, endian);

      if (available < lengthBytes + bodyLength) break;

      final bodyStart = _offset + lengthBytes;
      final bodyEnd = bodyStart + bodyLength;
      messages.add(Uint8List.fromList(_buffer.sublist(bodyStart, bodyEnd)));

      _offset = bodyEnd;
      _compactIfNeeded();
    }

    return messages;
  }

  void _append(List<int> chunk) {
    if (chunk.isEmpty) return;

    if (_offset > 0) {
      _compactIfNeeded(force: true);
    }

    final old = _buffer;
    final next = Uint8List(old.length + chunk.length);
    next.setRange(0, old.length, old);
    next.setRange(old.length, old.length + chunk.length, chunk);
    _buffer = next;
  }

  void _compactIfNeeded({bool force = false}) {
    if (_offset == 0) return;
    if (!force && _offset < 4096) return;

    if (_offset >= _buffer.length) {
      _buffer = Uint8List(0);
      _offset = 0;
      return;
    }

    final remaining = _buffer.length - _offset;
    final next = Uint8List(remaining);
    next.setRange(0, remaining, _buffer, _offset);
    _buffer = next;
    _offset = 0;
  }
}
