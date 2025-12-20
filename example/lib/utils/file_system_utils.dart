import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/base_data.dart';

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

  /// 判断指定目录下是否存在满足前缀的基础数据文件
  static Future<bool> hasFileWithPrefix(
    String directoryPath,
    BaseDataFilePrefix prefix,
  ) async {
    if (!await directoryExists(directoryPath)) {
      return false;
    }

    try {
      final directory = Directory(directoryPath);
      print('[FileSystemUtils] 检查目录: $directoryPath');
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }

        final fileName = p.basename(entity.path);
        print('[FileSystemUtils] 检查文件: $fileName');
        if (prefix.matches(fileName)) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }

    return false;
  }
}
