import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging_util/logging_util.dart';
import 'package:path_provider/path_provider.dart';

/// 应用目录工具类
/// 提供统一的应用目录访问方法
class AppDirectories {
  static const _logTag = '[AppDirectories]';

  /// 获取内部存储的Download目录
  /// 外部存储目录：/storage/emulated/0/Download
  /// 用户可以通过文件管理器访问此目录
  static Future<Directory> getFilesDirectory() async {
    try {
      // getExternalStorageDirectory() 返回外部存储目录
      // 通常是 /storage/emulated/0/Android/data/包名/files
      // 但我们使用Download目录，用户更容易访问
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        LogUtil.w('$_logTag 外部存储不可用，回退到内部目录');
        return await getApplicationSupportDirectory();
      }

      // 构建Download目录路径：/storage/emulated/0/Download
      final downloadDir = Directory('/storage/emulated/0/Download');

      // 确保目录存在
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
        LogUtil.i('$_logTag 创建 Download 目录: ${downloadDir.path}');
      }

      LogUtil.d('$_logTag 使用 Download 目录: ${downloadDir.path}');
      return downloadDir;
    } on MissingPluginException catch (e) {
      // 未找到平台实现时回退
      LogUtil.e('$_logTag 插件未注册，回退内部目录: $e');
      return await getApplicationSupportDirectory();
    } on PlatformException catch (e) {
      LogUtil.e('$_logTag 获取外部目录失败，回退内部目录: $e');
      return await getApplicationSupportDirectory();
    }
  }

  /// 获取pda.zip文件的完整路径
  static Future<String> getPdaZipPath() async {
    final filesDir = await getFilesDirectory();
    final path = '${filesDir.path}/pda.zip';
    LogUtil.d('$_logTag pda.zip 路径: $path');
    return path;
  }

  /// 检查pda.zip文件是否存在
  static Future<bool> pdaZipExists() async {
    final zipPath = await getPdaZipPath();
    final exists = await File(zipPath).exists();
    LogUtil.d('$_logTag pda.zip exists=$exists path=$zipPath');
    return exists;
  }

  /// 获取pda.zip文件对象
  static Future<File> getPdaZipFile() async {
    final zipPath = await getPdaZipPath();
    return File(zipPath);
  }

  /// 解压pda.zip文件到同名文件夹
  /// [onProgress] 解压进度回调 (0-1, 当前文件名)
  /// 返回解压后的目录路径
  static Future<String?> extractPdaZip({
    void Function(double progress, String fileName)? onProgress,
  }) async {
    try {
      final zipFile = await getPdaZipFile();

      if (!await zipFile.exists()) {
        LogUtil.w('$_logTag [Extract] pda.zip 文件不存在');
        return null;
      }

      final filesDir = await getFilesDirectory();
      final pdaDir = Directory('${filesDir.path}/pda');
      final extractDir = filesDir; // 直接解压到Download目录

      LogUtil.i('$_logTag [Extract] 开始解压 ${zipFile.path} 到 ${extractDir.path}');

      // 确保 pda 目录存在，若存在则清空
      if (await pdaDir.exists()) {
        // 删除已有内容，保留目录
        await _clearDirectory(pdaDir);
        LogUtil.i('$_logTag [Extract] 清空已存在的 pda 目录: ${pdaDir.path}');
      } else {
        await pdaDir.create(recursive: true);
        LogUtil.i('$_logTag [Extract] 创建 pda 目录: ${pdaDir.path}');
      }

      // 读取ZIP文件
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final totalBytes = archive.files
          .where((file) => file.isFile)
          .fold<int>(0, (sum, file) => sum + (file.size ?? 0));
      var processed = 0;

      // 解压文件
      int extractedCount = 0;
      for (final file in archive) {
        final filename = file.name;
        final filePath = '${extractDir.path}/$filename';

        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(filePath);

          // 确保父目录存在
          await outFile.parent.create(recursive: true);

          // 写入文件
          await outFile.writeAsBytes(data);
          extractedCount++;

          processed += file.size ?? data.length;
          if (onProgress != null && totalBytes > 0) {
            onProgress(
              (processed / totalBytes).clamp(0, 1),
              filename,
            );
          }
        } else {
          // 创建目录
          final dir = Directory(filePath);
          await dir.create(recursive: true);

          LogUtil.d('$_logTag [Extract] 创建目录: $filename');
        }
      }

      LogUtil.i('$_logTag [Extract] 解压完成，共解压 $extractedCount 个文件');
      onProgress?.call(1, '完成');

      return pdaDir.path;
    } catch (e) {
      LogUtil.e('$_logTag [Extract] 解压失败: $e');
      return null;
    }
  }

  /// 清空目录下的所有文件和子目录，但保留目录本身
  static Future<void> _clearDirectory(Directory dir) async {
    await for (final entity in dir.list(recursive: false)) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (e) {
        LogUtil.w('$_logTag [Extract] 删除文件失败: $e');
      }
    }
  }

  /// 获取解压后的pda目录
  static Future<Directory> getPdaExtractDirectory() async {
    final filesDir = await getFilesDirectory();
    return Directory('${filesDir.path}/pda');
  }

  /// 检查pda目录是否存在
  static Future<bool> pdaDirectoryExists() async {
    final pdaDir = await getPdaExtractDirectory();
    return pdaDir.exists();
  }

  /// 获取解压后目录的文件列表信息
  static Future<Map<String, dynamic>> getPdaDirectoryInfo() async {
    try {
      final pdaDir = await getPdaExtractDirectory();

      if (!await pdaDir.exists()) {
        return {
          'exists': false,
          'fileCount': 0,
          'files': <String>[],
        };
      }

      final files = await pdaDir.list(recursive: true).toList();
      final fileNames = files
          .whereType<File>()
          .map((file) => file.path.split('/').last)
          .toList();

      return {
        'exists': true,
        'fileCount': fileNames.length,
        'files': fileNames,
        'path': pdaDir.path,
      };
    } catch (e) {
      LogUtil.e('$_logTag [Info] 获取目录信息失败: $e');
      return {
        'exists': false,
        'fileCount': 0,
        'files': <String>[],
        'error': e.toString(),
      };
    }
  }
}
