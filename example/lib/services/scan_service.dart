import 'dart:convert';
import 'dart:io';

import 'package:logging_util/logging_util.dart';
import 'package:path/path.dart' as p;

import '../utils/app_directories.dart';

class OperationResult {
  final String status;
  final String snack;

  const OperationResult({
    required this.status,
    required this.snack,
  });
}

class DocumentData {
  final String title;
  final Map<String, String> scalar;
  final Map<String, List<Map<String, dynamic>>> tables;
  final String path;

  const DocumentData({
    required this.title,
    required this.scalar,
    required this.tables,
    required this.path,
  });
}

/// 负责处理扫码结果与 zip 解压逻辑
class ScanService {
  const ScanService();

  /// 在 pda 目录查找与条码同名的文件（不含扩展名），解析 JSON 返回业务数据
  Future<DocumentData?> loadDocument(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      LogUtil.w('[Scan] 收到空条码，忽略');
      return null;
    }

    final extractDir = await AppDirectories.getPdaExtractDirectory();
    if (!await extractDir.exists()) {
      LogUtil.w('[Scan] 解压目录不存在: ${extractDir.path}');
      return null;
    }

    File? target;
    await for (final entity in extractDir.list(recursive: true)) {
      if (entity is! File) continue;
      if (p.basenameWithoutExtension(entity.path) == trimmed) {
        target = entity;
        break;
      }
    }

    if (target == null) {
      LogUtil.w('[Scan] 文件未找到: $trimmed');
      return null;
    }

    try {
      final content = await target.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        LogUtil.w('[Scan] 文件格式非 Map，无法解析: ${target.path}');
        return null;
      }
      final map = Map<String, dynamic>.from(decoded as Map);
      final title = map['title'] as String? ?? trimmed;
      final data = map['data'] as Map<String, dynamic>? ?? {};

      final scalar = <String, String>{};
      final tables = <String, List<Map<String, dynamic>>>{};

      data.forEach((key, value) {
        if (value is List) {
          final list = value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          tables[key] = list;
        } else {
          scalar[key] = '${value ?? ''}';
        }
      });

      LogUtil.i('[Scan] 解析文件成功: ${target.path}');
      return DocumentData(
        title: title,
        scalar: scalar,
        tables: tables,
        path: target.path,
      );
    } catch (e) {
      LogUtil.e('[Scan] 解析文件失败: $e');
      return null;
    }
  }

  /// 仅检查 pda.zip 是否存在
  Future<(bool, OperationResult)> checkZipExists() async {
    final zipPath = await AppDirectories.getPdaZipPath();
    final exists = await AppDirectories.pdaZipExists();

    if (!exists) {
      LogUtil.w('[Zip] 未找到 pda.zip, 期望: $zipPath');
      return (
        false,
        OperationResult(
          status: 'pda.zip 未找到',
          snack: '未找到 pda.zip，路径：$zipPath',
        )
      );
    }

    LogUtil.i('[Zip] 找到 pda.zip: $zipPath');
    return (
      true,
      OperationResult(
        status: 'pda.zip 已存在',
        snack: '找到 pda.zip：$zipPath',
      )
    );
  }

  /// 解压 pda.zip（不设超时，失败时返回错误）
  Future<OperationResult> extractZip({
    void Function(double progress, String fileName)? onDeleteProgress,
    void Function(double progress, String fileName)? onExtractProgress,
  }) async {
    final extractPath = await AppDirectories.extractPdaZip(
      onDeleteProgress: onDeleteProgress,
      onExtractProgress: onExtractProgress,
    );
    if (extractPath == null) {
      return const OperationResult(
        status: '解压失败',
        snack: 'pda.zip 解压失败',
      );
    }

    LogUtil.i('[Zip] 解压完成: $extractPath');
    return OperationResult(
      status: '解压完成',
      snack: 'pda.zip 解压完成：$extractPath',
    );
  }
}
