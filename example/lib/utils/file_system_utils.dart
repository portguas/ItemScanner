import 'dart:io';

import 'package:path/path.dart' as p;

/// 文件系统相关的工具方法
class FileSystemUtils {
  const FileSystemUtils._();

  /// 检查目录是否存在
  static Future<bool> directoryExists(String directoryPath) async {
    if (directoryPath.isEmpty) {
      return false;
    }
    try {
      final directory = Directory(directoryPath);
      return await directory.exists();
    } catch (_) {
      return false;
    }
  }

  /// 检查指定路径的文件是否存在
  static Future<bool> fileExists(String filePath) async {
    if (filePath.isEmpty) {
      return false;
    }
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }
}
