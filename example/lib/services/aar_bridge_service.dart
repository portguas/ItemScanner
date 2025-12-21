import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// UniPluginScanSDK桥接服务
/// 用于Flutter与Android原生扫描SDK之间的通信
class ScannerService {
  final MethodChannel _flutterToNativeChannel =
      const MethodChannel('com.example.pda/flutter_to_native');

  static ScannerService? _instance;
  static const String _logName = 'ScannerService';

  // 扫描回调函数
  Function(ScanResult)? _scanCallback;

  /// 单例模式
  static ScannerService get instance {
    _instance ??= ScannerService._();
    return _instance!;
  }

  ScannerService._();

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message,
        name: _logName, error: error, stackTrace: stackTrace);
  }

  /// 初始化扫描器
  ///
  /// 返回初始化结果
  Future<Map<String, dynamic>> initializeScanner() async {
    _log('initializeScanner() invoked');
    try {
      final result =
          await _flutterToNativeChannel.invokeMethod('initializeScanner');
      _log('initializeScanner() success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('initializeScanner() failed: ${e.message}', error: e);
      throw ScannerException('扫描器初始化失败: ${e.message}', e.code);
    }
  }

  /// 开始扫描
  ///
  /// 返回扫描结果，如果扫描被取消则返回cancelled=true
  Future<ScanResult> startScan() async {
    _log('startScan() invoked');
    try {
      final result = await _flutterToNativeChannel.invokeMethod('startScan');
      _log('startScan() success: $result');
      return ScanResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      _log('startScan() failed: ${e.message}', error: e);
      throw ScannerException('开始扫描失败: ${e.message}', e.code);
    }
  }

  /// 停止扫描
  ///
  /// 返回停止结果
  Future<Map<String, dynamic>> stopScan() async {
    _log('stopScan() invoked');
    try {
      final result = await _flutterToNativeChannel.invokeMethod('stopScan');
      _log('stopScan() success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('stopScan() failed: ${e.message}', error: e);
      throw ScannerException('停止扫描失败: ${e.message}', e.code);
    }
  }

  /// 设置扫描引擎开关
  ///
  /// [enabled] 是否启用扫描引擎
  Future<Map<String, dynamic>> setScannerEnabled(bool enabled) async {
    _log('setScannerEnabled($enabled) invoked');
    try {
      final result = await _flutterToNativeChannel.invokeMethod(
          'setScannerEnabled', enabled);
      _log('setScannerEnabled($enabled) success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('setScannerEnabled($enabled) failed: ${e.message}', error: e);
      throw ScannerException('设置扫描引擎失败: ${e.message}', e.code);
    }
  }

  /// 设置输出模式
  ///
  /// [mode] 输出模式 0：广播模式 1：键盘模式 2：广播模式+键盘模式
  Future<Map<String, dynamic>> setOutputMode(OutputMode mode) async {
    _log('setOutputMode(${mode.value}) invoked');
    try {
      final result = await _flutterToNativeChannel.invokeMethod(
          'setOutputMode', mode.value);
      _log('setOutputMode(${mode.value}) success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('setOutputMode(${mode.value}) failed: ${e.message}', error: e);
      throw ScannerException('设置输出模式失败: ${e.message}', e.code);
    }
  }

  /// 设置触发模式
  ///
  /// [mode] 触发模式 0：自动模式 1：连扫模式 2：手动模式
  Future<Map<String, dynamic>> setTriggerMode(TriggerMode mode) async {
    _log('setTriggerMode(${mode.value}) invoked');
    try {
      final result = await _flutterToNativeChannel.invokeMethod(
          'setTriggerMode', mode.value);
      _log('setTriggerMode(${mode.value}) success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('setTriggerMode(${mode.value}) failed: ${e.message}', error: e);
      throw ScannerException('设置触发模式失败: ${e.message}', e.code);
    }
  }

  /// 设置扫描锁定
  ///
  /// [locked] 是否锁定扫描
  Future<Map<String, dynamic>> setScanLock(bool locked) async {
    _log('setScanLock($locked) invoked');
    try {
      final result =
          await _flutterToNativeChannel.invokeMethod('setScanLock', locked);
      _log('setScanLock($locked) success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('setScanLock($locked) failed: ${e.message}', error: e);
      throw ScannerException('设置扫描锁定失败: ${e.message}', e.code);
    }
  }

  /// 设置提示音
  ///
  /// [enabled] 是否启用提示音
  Future<Map<String, dynamic>> setBeepEnabled(bool enabled) async {
    _log('setBeepEnabled($enabled) invoked');
    try {
      final result =
          await _flutterToNativeChannel.invokeMethod('setBeepEnabled', enabled);
      _log('setBeepEnabled($enabled) success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('setBeepEnabled($enabled) failed: ${e.message}', error: e);
      throw ScannerException('设置提示音失败: ${e.message}', e.code);
    }
  }

  /// 设置震动
  ///
  /// [enabled] 是否启用震动
  Future<Map<String, dynamic>> setVibrateEnabled(bool enabled) async {
    _log('setVibrateEnabled($enabled) invoked');
    try {
      final result = await _flutterToNativeChannel.invokeMethod(
          'setVibrateEnabled', enabled);
      _log('setVibrateEnabled($enabled) success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('setVibrateEnabled($enabled) failed: ${e.message}', error: e);
      throw ScannerException('设置震动失败: ${e.message}', e.code);
    }
  }

  /// 获取扫描器信息
  ///
  /// 返回扫描器信息
  Future<ScannerInfo> getScannerInfo() async {
    _log('getScannerInfo() invoked');
    try {
      final result =
          await _flutterToNativeChannel.invokeMethod('getScannerInfo');
      _log('getScannerInfo() success: $result');
      return ScannerInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      _log('getScannerInfo() failed: ${e.message}', error: e);
      throw ScannerException('获取扫描器信息失败: ${e.message}', e.code);
    }
  }

  /// 注销广播接收器
  ///
  /// 返回注销结果
  Future<Map<String, dynamic>> unregisterReceiver() async {
    _log('unregisterReceiver() invoked');
    try {
      final result =
          await _flutterToNativeChannel.invokeMethod('unregisterReceiver');
      _log('unregisterReceiver() success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('unregisterReceiver() failed: ${e.message}', error: e);
      throw ScannerException('注销接收器失败: ${e.message}', e.code);
    }
  }

  /// 注册扫描回调
  ///
  /// [callback] 扫描结果回调函数
  /// 返回注册结果
  Future<Map<String, dynamic>> registerScanCallback(
      Function(ScanResult) callback) async {
    _log('registerScanCallback() invoked');
    try {
      _scanCallback = callback;
      final result =
          await _flutterToNativeChannel.invokeMethod('registerScanCallback');
      _log('registerScanCallback() success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('registerScanCallback() failed: ${e.message}', error: e);
      _scanCallback = null;
      throw ScannerException('注册扫描回调失败: ${e.message}', e.code);
    }
  }

  /// 取消注册扫描回调
  ///
  /// 返回取消注册结果
  Future<Map<String, dynamic>> unregisterScanCallback() async {
    _log('unregisterScanCallback() invoked');
    try {
      final result =
          await _flutterToNativeChannel.invokeMethod('unregisterScanCallback');
      _scanCallback = null;
      _log('unregisterScanCallback() success: $result');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _log('unregisterScanCallback() failed: ${e.message}', error: e);
      throw ScannerException('取消注册扫描回调失败: ${e.message}', e.code);
    }
  }

  /// 处理来自原生端的扫描回调
  Future<void> _handleScanCallback(MethodCall call) async {
    _log('_handleScanCallback() received: ${call.method}');

    if (call.method == 'onScanResult') {
      try {
        final Map<String, dynamic> resultMap =
            Map<String, dynamic>.from(call.arguments);
        final scanResult = ScanResult.fromMap(resultMap);
        _log('_handleScanCallback() parsed result: $scanResult');

        // 调用注册的回调函数
        if (_scanCallback != null) {
          _scanCallback!(scanResult);
          _log('_handleScanCallback() callback invoked successfully');
        } else {
          _log('_handleScanCallback() no callback registered, ignoring result');
        }
      } catch (e) {
        _log('_handleScanCallback() failed to parse result', error: e);
      }
    } else {
      _log('_handleScanCallback() unknown method: ${call.method}');
    }
  }
}

/// 扫描器异常类
class ScannerException implements Exception {
  final String message;
  final String? code;

  const ScannerException(this.message, [this.code]);

  @override
  String toString() =>
      'ScannerException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// 扫描结果
class ScanResult {
  final bool success;
  final String? barcode;
  final String? format;
  final int? timestamp;
  final String? message;
  final bool cancelled;

  const ScanResult({
    required this.success,
    this.barcode,
    this.format,
    this.timestamp,
    this.message,
    this.cancelled = false,
  });

  factory ScanResult.fromMap(Map<String, dynamic> map) {
    return ScanResult(
      success: map['success'] ?? false,
      barcode: map['barcode']?.toString(), // 确保转换为字符串
      format: map['format']?.toString(),
      timestamp: map['timestamp'] is int ? map['timestamp'] : int.tryParse(map['timestamp']?.toString() ?? ''),
      message: map['message']?.toString(),
      cancelled: map['cancelled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'barcode': barcode,
      'format': format,
      'timestamp': timestamp,
      'message': message,
      'cancelled': cancelled,
    };
  }

  @override
  String toString() {
    return 'ScanResult(success: $success, barcode: $barcode, format: $format, timestamp: $timestamp, message: $message, cancelled: $cancelled)';
  }
}

/// 扫描器信息
class ScannerInfo {
  final String name;
  final String version;
  final String type;
  final String description;
  final bool isScanning;

  const ScannerInfo({
    required this.name,
    required this.version,
    required this.type,
    required this.description,
    required this.isScanning,
  });

  factory ScannerInfo.fromMap(Map<String, dynamic> map) {
    return ScannerInfo(
      name: map['name'] ?? '',
      version: map['version'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      isScanning: map['isScanning'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'type': type,
      'description': description,
      'isScanning': isScanning,
    };
  }

  @override
  String toString() {
    return 'ScannerInfo(name: $name, version: $version, type: $type, description: $description, isScanning: $isScanning)';
  }
}

/// 输出模式枚举
enum OutputMode {
  broadcast(0, '广播模式'),
  keyboard(1, '键盘模式'),
  both(2, '广播模式+键盘模式');

  const OutputMode(this.value, this.description);

  final int value;
  final String description;
}

/// 触发模式枚举
enum TriggerMode {
  auto(0, '自动模式'),
  continuous(1, '连扫模式'),
  manual(2, '手动模式');

  const TriggerMode(this.value, this.description);

  final int value;
  final String description;
}
