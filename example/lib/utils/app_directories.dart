import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:logging_util/logging_util.dart';
import 'package:path/path.dart' as p;
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
  /// [onDeleteProgress] 删除进度回调 (0-1, 当前文件/目录)
  /// [onExtractProgress] 解压进度回调 (0-1, 当前文件名)
  /// 返回解压后的目录路径
  static Future<String?> extractPdaZip({
    void Function(double progress, String fileName)? onDeleteProgress,
    void Function(double progress, String fileName)? onExtractProgress,
  }) async {
    try {
      final zipFile = await getPdaZipFile();

      if (!await zipFile.exists()) {
        LogUtil.w('$_logTag [Extract] pda.zip 文件不存在');
        return null;
      }

      final filesDir = await getFilesDirectory();
      final pdaDir = Directory('${filesDir.path}/pda');
      LogUtil.i('$_logTag [Extract] 开始解压 ${zipFile.path} 到 ${pdaDir.path}');

      // 确保 pda 目录存在，若存在则清空
      if (await pdaDir.exists()) {
        await _deleteDirectoryFast(
          pdaDir,
          onProgress: (progress, action) {
            onDeleteProgress?.call(progress, action);
          },
        );
      }
      await pdaDir.create(recursive: true);
      LogUtil.i('$_logTag [Extract] 创建/清空 pda 目录: ${pdaDir.path}');

      try {
        onExtractProgress?.call(0, '开始解压');
        final watch = Stopwatch()..start();

        await ZipFile.extractToDirectory(
          zipFile: zipFile,
          destinationDir: pdaDir,
          onExtracting: (zipEntry, progress) {
            if (onExtractProgress != null) {
              final name = zipEntry.name.isEmpty ? '...' : zipEntry.name;
              final normalized = (progress / 100).clamp(0.0, 1.0);
              onExtractProgress(normalized, name);
            }
            return ZipFileOperation.includeItem;
          },
        );

        watch.stop();
        LogUtil.i(
          '$_logTag [Extract] flutter_archive 解压完成，耗时 ${watch.elapsedMilliseconds}ms',
        );

        await _flattenNestedPda(pdaDir);
        onExtractProgress?.call(1, '完成');

        return pdaDir.path;
      } finally {
        // 无需手动关闭，flutter_archive 内部处理
      }
    } catch (e) {
      LogUtil.e('$_logTag [Extract] 解压失败: $e');
      return null;
    }
  }

  /// 优先用递归删除整个目录，失败时回退到逐个删除（适合大量小文件场景）
  static Future<void> _deleteDirectoryFast(
    Directory dir, {
    void Function(double progress, String action)? onProgress,
  }) async {
    try {
      if (!await dir.exists()) {
        onProgress?.call(1, '无需删除');
        return;
      }

      onProgress?.call(0, '重命名待删目录');
      LogUtil.d('开始重命名待删目录: ${dir.path}');
      final tempPath =
          '${dir.path}_to_be_deleted_${DateTime.now().microsecondsSinceEpoch}';
      final tempDir = Directory(tempPath);

      final renameWatch = Stopwatch()..start();
      await dir.rename(tempPath); // O(1) 重命名，避免长时间阻塞
      renameWatch.stop();
      LogUtil.d(
        '$_logTag [Extract] 重命名耗时 ${renameWatch.elapsedMilliseconds}ms -> ${tempDir.path}',
      );
      onProgress?.call(1, '后台删除中');

      // 后台使用隔离线程删除，避免阻塞主 Isolate
      unawaited(Isolate.run(() async {
        try {
          await tempDir.delete(recursive: true);
          LogUtil.d('$_logTag [Extract] 后台清理完成: ${tempDir.path}');
        } catch (e) {
          LogUtil.w('$_logTag [Extract] 后台清理失败: $e');
        }
      }));
    } catch (e) {
      LogUtil.w('$_logTag [Extract] 快速删除失败，回退直接删除: $e');
      onProgress?.call(0, '直接删除');
      await dir.delete(recursive: true);
      onProgress?.call(1, '删除完成');
    }
  }

  /// 处理解压后出现的 pda/pda 嵌套目录
  static Future<void> _flattenNestedPda(Directory pdaDir) async {
    final nested = Directory(p.join(pdaDir.path, 'pda'));
    if (!await nested.exists()) return;

    final entries = await nested.list().toList();
    for (final entity in entries) {
      final targetPath = p.join(pdaDir.path, p.basename(entity.path));
      try {
        await entity.rename(targetPath);
      } catch (e) {
        LogUtil.w('$_logTag [Extract] 移动文件失败 $targetPath: $e');
      }
    }

    try {
      await nested.delete(recursive: true);
      LogUtil.i('$_logTag [Extract] 处理嵌套目录完成');
    } catch (e) {
      LogUtil.w('$_logTag [Extract] 删除嵌套目录失败: $e');
    }
  }

  /// 清空目录下的所有文件和子目录，但保留目录本身
  static Future<void> _clearDirectory(
    Directory dir, {
    void Function(double progress, String action)? onProgress,
  }) async {
    if (!await dir.exists()) {
      onProgress?.call(1, '删除完成');
      return;
    }

    final entities = await dir.list(recursive: false).toList();
    final total = entities.length;
    var processed = 0;

    for (final entity in entities) {
      try {
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path;
        onProgress?.call(
          total == 0 ? 0 : (processed / total).clamp(0, 1),
          '删除: $name',
        );

        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
        processed++;
      } catch (e) {
        LogUtil.w('$_logTag [Extract] 删除文件失败: $e');
      }
    }

    onProgress?.call(1, '删除完成');
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
