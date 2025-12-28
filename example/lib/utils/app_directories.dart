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
  static String _extractDirName = 'scm';

  /// 根据 zip 路径设置解压目录名（与 zip 同名，不含扩展名）
  static void setExtractDirNameFromZip(String? zipPath) {
    _extractDirName = 'scm';
  }

  /// 获取应用私有目录（用于保存 zip 与解压文件）
  /// 该目录不需要外部存储权限，但用户无法直接在文件 App 中访问
  static Future<Directory> getFilesDirectory() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      if (!await supportDir.exists()) {
        await supportDir.create(recursive: true);
      }
      LogUtil.d('$_logTag 使用应用私有目录: ${supportDir.path}');
      return supportDir;
    } on MissingPluginException catch (e) {
      // 未找到平台实现时回退
      LogUtil.e('$_logTag 插件未注册，回退内部目录: $e');
      return await getApplicationSupportDirectory();
    } on PlatformException catch (e) {
      LogUtil.e('$_logTag 获取应用目录失败，回退内部目录: $e');
      return await getApplicationSupportDirectory();
    }
  }

  /// 获取scm.zip文件的完整路径
  static Future<String> getPdaZipPath() async {
    final filesDir = await getFilesDirectory();
    final path = '${filesDir.path}/scm.zip';
    LogUtil.d('$_logTag scm.zip 路径: $path');
    return path;
  }

  /// 检查scm.zip文件是否存在
  static Future<bool> pdaZipExists() async {
    final zipPath = await getPdaZipPath();
    final exists = await File(zipPath).exists();
    LogUtil.d('$_logTag scm.zip exists=$exists path=$zipPath');
    return exists;
  }

  /// 获取scm.zip文件对象
  static Future<File> getPdaZipFile() async {
    final zipPath = await getPdaZipPath();
    return File(zipPath);
  }

  /// 将选取的 zip 文件保存到应用私有目录（覆盖已有同名文件）
  /// 优先使用源文件路径复制，其次使用内存数据或流写入
  static Future<String?> saveZipFile({
    required String fileName,
    String? sourcePath,
    List<int>? bytes,
    Stream<List<int>>? readStream,
  }) async {
    try {
      final filesDir = await getFilesDirectory();
      final normalizedName = p.basename(fileName);
      final destFile = File(p.join(filesDir.path, normalizedName));

      if (sourcePath != null) {
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(destFile.path);
          LogUtil.i('$_logTag 保存 zip（复制）: ${destFile.path} <- $sourcePath');
          return destFile.path;
        }
      }

      if (bytes != null) {
        await destFile.writeAsBytes(bytes, flush: true);
        LogUtil.i('$_logTag 保存 zip（内存数据）: ${destFile.path}');
        return destFile.path;
      }

      if (readStream != null) {
        final sink = destFile.openWrite();
        try {
          await sink.addStream(readStream);
          await sink.flush();
          LogUtil.i('$_logTag 保存 zip（流）: ${destFile.path}');
        } finally {
          await sink.close();
        }
        return destFile.path;
      }

      LogUtil.w('$_logTag 未提供可用的 zip 文件数据: $fileName');
      return null;
    } catch (e) {
      LogUtil.e('$_logTag 保存 zip 文件失败: $e');
      return null;
    }
  }

  /// 解压scm.zip文件到同名文件夹
  /// [onDeleteProgress] 删除进度回调 (0-1, 当前文件/目录)
  /// [onExtractProgress] 解压进度回调 (0-1, 当前文件名)
  /// 返回解压后的目录路径
  static Future<String?> extractPdaZip({
    void Function(double progress, String fileName)? onDeleteProgress,
    void Function(double progress, String fileName)? onExtractProgress,
    String? zipPath,
  }) async {
    try {
      setExtractDirNameFromZip(zipPath);

      final zipFile = zipPath != null ? File(zipPath) : await getPdaZipFile();

      if (!await zipFile.exists()) {
        LogUtil.w('$_logTag [Extract] zip 文件不存在: ${zipFile.path}');
        return null;
      }

      final filesDir = await getFilesDirectory();
      final targetDir = Directory(p.join(filesDir.path, _extractDirName));
      LogUtil.i('$_logTag [Extract] 开始解压 ${zipFile.path} 到 ${targetDir.path}');

      // 若目标目录存在，快速重命名+后台删除（不存在则直接跳过）
      await _deleteDirectoryFast(
        targetDir,
        onProgress: (progress, action) {
          onDeleteProgress?.call(progress, action);
        },
      );
      final stagingDir = Directory(
        p.join(
          filesDir.path,
          '${_extractDirName}_staging_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
      await stagingDir.create(recursive: true);

      try {
        onExtractProgress?.call(0, '开始解压');
        final watch = Stopwatch()..start();

        await ZipFile.extractToDirectory(
          zipFile: zipFile,
          destinationDir: stagingDir,
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

        // 目标：无论 zip 内部根目录叫什么，都解压到 scm/ 下（不出现 scm/pda/...）
        // 若 staging 下只有一个子目录且没有文件，则把该子目录直接重命名为 scm，避免逐文件移动
        final rootEntries = await stagingDir.list(recursive: false).toList();
        final rootDirs = rootEntries.whereType<Directory>().toList();
        final rootFiles = rootEntries.whereType<File>().toList();

        if (rootFiles.isEmpty && rootDirs.length == 1) {
          final rootDir = rootDirs.single;
          await rootDir.rename(targetDir.path);
          // 清理空的 staging 目录
          try {
            await stagingDir.delete(recursive: true);
          } catch (_) {}
        } else {
          await stagingDir.rename(targetDir.path);
        }

        onExtractProgress?.call(1, '完成');
        return targetDir.path;
      } catch (e) {
        // 失败时尽量清理 staging，避免残留文件占用空间
        try {
          if (await stagingDir.exists()) {
            await stagingDir.delete(recursive: true);
          }
        } catch (_) {}
        rethrow;
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
    final tempPath =
        '${dir.path}_to_be_deleted_${DateTime.now().microsecondsSinceEpoch}';
    final tempDir = Directory(tempPath);

    try {
      onProgress?.call(0, '重命名待删目录');
      LogUtil.d('$_logTag [Extract] 开始重命名待删目录: ${dir.path}');

      final renameWatch = Stopwatch()..start();
      await dir.rename(tempPath);
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
        } on FileSystemException catch (e) {
          LogUtil.w('$_logTag [Extract] 后台清理失败: ${e.message}');
        } catch (e) {
          LogUtil.w('$_logTag [Extract] 后台清理失败: $e');
        }
      }));
    } on FileSystemException catch (e) {
      // 目录不存在：无需处理
      if (e.osError?.errorCode == 2) {
        onProgress?.call(1, '无需删除');
        return;
      }

      LogUtil.w('$_logTag [Extract] 快速删除失败，回退直接删除: ${e.message}');
      onProgress?.call(0, '直接删除');
      try {
        await dir.delete(recursive: true);
        onProgress?.call(1, '删除完成');
      } on FileSystemException catch (e) {
        if (e.osError?.errorCode == 2) {
          onProgress?.call(1, '无需删除');
          return;
        }
        rethrow;
      }
    } catch (e) {
      LogUtil.w('$_logTag [Extract] 快速删除失败，回退直接删除: $e');
      onProgress?.call(0, '直接删除');
      await dir.delete(recursive: true);
      onProgress?.call(1, '删除完成');
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
    return Directory(p.join(filesDir.path, _extractDirName));
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
