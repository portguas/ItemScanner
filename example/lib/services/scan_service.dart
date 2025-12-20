import 'dart:io';

import 'package:logging_util/logging_util.dart';
import 'package:path/path.dart' as p;

import '../utils/app_directories.dart';

class ScanResult {
  final String? barcode;
  final Map<String, dynamic> raw;

  ScanResult({
    required this.raw,
    this.barcode,
  });

  factory ScanResult.fromMap(Map<String, dynamic> map) {
    final code = map['barcode'] as String? ?? map['data'] as String?;
    return ScanResult(
      raw: map,
      barcode: code,
    );
  }
}

class OperationResult {
  final String status;
  final String snack;

  const OperationResult({
    required this.status,
    required this.snack,
  });
}

/// 负责处理扫码结果与 zip 解压逻辑
class ScanService {
  const ScanService();

  /// 根据条码在解压目录查找同名文件
  Future<OperationResult> handleBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return const OperationResult(
        status: '条码为空',
        snack: '条码为空',
      );
    }

    LogUtil.i('[Scan] 收到条码: $trimmed');

    final extractDir = await AppDirectories.getPdaExtractDirectory();
    final dirPath = extractDir.path;
    final dirExists = await extractDir.exists();
    if (!dirExists) {
      LogUtil.w('[Scan] 解压目录不存在: $dirPath');
      return OperationResult(
        status: '解压目录不存在',
        snack: '解压目录不存在：$dirPath',
      );
    }

    final targetPath = p.join(dirPath, trimmed);
    final file = File(targetPath);
    final exists = await file.exists();
    if (!exists) {
      LogUtil.w('[Scan] 文件未找到: $targetPath');
      return OperationResult(
        status: '文件未找到',
        snack: '文件未找到：$trimmed',
      );
    }

    LogUtil.i('[Scan] 找到文件: $targetPath');
    await _onPdaFileFound(file);
    return OperationResult(
      status: '找到文件：$trimmed',
      snack: '找到文件：$trimmed',
    );
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
    void Function(double progress, String fileName)? onProgress,
  }) async {
    final extractPath = await AppDirectories.extractPdaZip(
      onProgress: onProgress,
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

  Future<void> _onPdaFileFound(File file) async {
    // TODO: 实现找到文件后的处理逻辑
  }
}
