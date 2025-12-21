import 'dart:async';
import 'package:flutter/foundation.dart';
import 'aar_bridge_service.dart';

/// 扫描器初始化服务
/// 负责在应用启动时自动初始化扫描器，不阻塞主线程
class ScannerInitializationService {
  static ScannerInitializationService? _instance;
  static ScannerInitializationService get instance {
    _instance ??= ScannerInitializationService._();
    return _instance!;
  }

  ScannerInitializationService._();

  final ScannerService _scannerService = ScannerService.instance;
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// 扫描器是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在初始化
  bool get isInitializing => _isInitializing;

  /// 应用启动时自动初始化扫描器
  /// 在后台线程执行，不阻塞主线程
  Future<void> initializeOnAppStart() async {
    if (_isInitialized || _isInitializing) {
      return;
    }

    _isInitializing = true;

    // 在后台执行初始化，不阻塞主线程
    unawaited(_performBackgroundInitialization());
  }

  /// 在后台执行扫描器初始化
  Future<void> _performBackgroundInitialization() async {
    try {
      // 等待应用完全启动
      await Future.delayed(const Duration(milliseconds: 1000));

      if (kDebugMode) {
        print('[Scanner] 开始后台初始化扫描器...');
      }

      // 重试机制：最多尝试3次
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          if (kDebugMode) {
            print('[Scanner] 第$attempt次初始化尝试...');
          }

          // 初始化扫描器
          final result = await _scannerService.initializeScanner();

          if (result['success'] == true) {
            if (kDebugMode) {
              print('[Scanner] 初始化成功！');
            }

            // 配置默认设置：自动模式 + 广播模式
            await _configureDefaultSettings();

            _isInitialized = true;
            _isInitializing = false;

            if (kDebugMode) {
              print('[Scanner] 扫描器已就绪，默认设置已配置');
            }
            return;
          } else {
            if (kDebugMode) {
              print('[Scanner] 第$attempt次初始化失败: ${result['message']}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('[Scanner] 第$attempt次初始化异常: $e');
          }
        }

        // 如果不是最后一次尝试，等待后重试
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 1000 * attempt));
        }
      }

      // 所有尝试都失败了
      if (kDebugMode) {
        print('[Scanner] 后台初始化失败，将在用户使用时再次尝试');
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// 配置默认扫描设置
  /// 自动触发模式 + 广播输出模式
  Future<void> _configureDefaultSettings() async {
    try {
      // 设置为广播模式
      await _scannerService.setOutputMode(OutputMode.broadcast);

      // 设置为自动触发模式
      await _scannerService.setTriggerMode(TriggerMode.auto);

      // 启用扫描引擎
      await _scannerService.setScannerEnabled(true);

      // 启用提示音和震动
      await _scannerService.setBeepEnabled(true);
      await _scannerService.setVibrateEnabled(true);

      if (kDebugMode) {
        print('[Scanner] 默认设置配置完成：自动模式 + 广播模式');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Scanner] 配置默认设置失败: $e');
      }
    }
  }

  /// 手动重新初始化（用于用户手动触发）
  Future<bool> reinitialize() async {
    if (_isInitializing) {
      return false;
    }

    _isInitialized = false;
    await initializeOnAppStart();

    // 等待初始化完成或超时
    int waitCount = 0;
    while (_isInitializing && waitCount < 50) {
      // 最多等待5秒
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    return _isInitialized;
  }

  /// 获取初始化状态信息
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isInitializing': _isInitializing,
    };
  }
}
