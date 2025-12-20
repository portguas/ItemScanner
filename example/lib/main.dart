import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging_util/logging_util.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:service_network/service_network.dart';
import 'package:ui_design_system/ui_design_system.dart';
import 'utils/app_directories.dart';
import 'utils/permission_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LogUtil.init(
    // 发生错误时上报到远程平台（如 Sentry/Firebase Crashlytics）。
    errorReporter: (message, error, stackTrace) {
      debugPrint('Report to crash platform: $message');
    },
    // 将 Error 级别日志写入文件（示例中仅打印，可结合 path_provider 写入持久化目录）。
    fileWriter: (line) {
      debugPrint('Write log to file: $line');
    },
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '物品扫描',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: '物品扫描'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MethodChannel _methodChannel =
      const MethodChannel('com.example.pda/native_to_flutter');


  String _status = 'Ready';
  bool _checkingZip = false;
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();

    // 应用进入首页时请求权限
    _requestPermissionsOnStart();

    _registerScanHandler();
  }

  void _registerScanHandler() {
    _methodChannel.setMethodCallHandler((call) async {
      LogUtil.d('收到新数据: ${call.arguments}, call.method=${call.method}');

      if (call.method == 'onScanResult') {
        try {
          // 先转换类型，确保类型安全
          final Map<String, dynamic> resultMap =
              Map<String, dynamic>.from(call.arguments);

          final result = ScanResult.fromMap(resultMap);

          if (result.barcode != null) {
            // await _processScanResultLegacy(context, result.barcode!);
          }
        } catch (e, stackTrace) {
          LogUtil.d('处理扫描结果时发生异常: $e');
          LogUtil.d('堆栈跟踪: $stackTrace');
        }
      } else {
        LogUtil.d('未知方法: ${call.method}');
      }
    });
  }

 /// 应用启动时请求权限
  Future<void> _requestPermissionsOnStart() async {
    if (_permissionsRequested) return;

    _permissionsRequested = true;

    try {
      if (kDebugMode) {
        LogUtil.d('[HomePage] 开始请求存储权限...');
      }

      final hasPermission =
          await PermissionService.requestAllStoragePermissions();

      if (kDebugMode) {
        LogUtil.d('[HomePage] 权限请求结果: $hasPermission');
      }

      if (!hasPermission && mounted) {
        // 权限被拒绝，显示提示（但不强制要求）
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('存储权限未授予，同步功能可能无法正常使用'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        LogUtil.e('[HomePage] 权限请求异常: $e');
      }
    }
  }

  void _makeRequest() async {
   
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _checkingZip ? null : _checkPdaZip,
            icon: Icon(Icons.drive_folder_upload_outlined),
            tooltip: '检查 pda.zip',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _status,
              style: AppTextStyles.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'Make Network Request',
              onPressed: _makeRequest,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkPdaZip() async {
    if (_checkingZip) return;
    LogUtil.i('[ZipCheck] 开始检查 pda.zip');
    setState(() {
      _checkingZip = true;
      _status = '正在检查 pda.zip...';
    });

    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const _ProgressDialog(message: '正在检查 pda.zip...');
      },
    );

    String result = '';
    try {
      final zipPath = await AppDirectories.getPdaZipPath().timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('获取 pda.zip 路径超时 (10s)'),
      );
      final exists = await AppDirectories.pdaZipExists().timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('检测 pda.zip 是否存在超时 (10s)'),
      );
      result =
          exists ? 'pda.zip 已存在：$zipPath' : '未找到 pda.zip，预期路径：$zipPath';
      LogUtil.i('[ZipCheck] exists=$exists path=$zipPath');
      if (mounted) {
        setState(() {
          _status = exists ? 'pda.zip 已存在' : 'pda.zip 未找到';
        });
      }
    } on TimeoutException catch (e) {
      result = '检查超时：${e.message ?? ''}';
      LogUtil.e('[ZipCheck] 超时: $result');
      if (mounted) {
        setState(() {
          _status = result;
        });
      }
    } catch (e) {
      result = '检查失败：$e';
      LogUtil.e('[ZipCheck] 失败: $e');
      if (mounted) {
        setState(() {
          _status = result;
        });
      }
    } finally {
      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
        setState(() {
          _checkingZip = false;
        });
      }
      LogUtil.i('[ZipCheck] 完成: $result');
    }
  }
}

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

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
