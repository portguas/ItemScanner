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
  /// 返回解压后的目录路径
  static Future<String?> extractPdaZip() async {
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

      // 如果pda目录已存在，先删除
      if (await pdaDir.exists()) {
        await pdaDir.delete(recursive: true);
        LogUtil.i('$_logTag [Extract] 删除已存在的 pda 目录: ${pdaDir.path}');
      }

      // 读取ZIP文件
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

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

          LogUtil.d('$_logTag [Extract] 解压文件: $filename (${data.length} bytes)');
        } else {
          // 创建目录
          final dir = Directory(filePath);
          await dir.create(recursive: true);

          LogUtil.d('$_logTag [Extract] 创建目录: $filename');
        }
      }

      LogUtil.i('$_logTag [Extract] 解压完成，共解压 $extractedCount 个文件');

      return pdaDir.path;
    } catch (e) {
      LogUtil.e('$_logTag [Extract] 解压失败: $e');
      return null;
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
