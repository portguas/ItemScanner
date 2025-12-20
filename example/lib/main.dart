import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging_util/logging_util.dart';
import 'package:ui_design_system/ui_design_system.dart';
import 'utils/permission_service.dart';
import 'services/scan_service.dart';

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
  final ScanService _scanService = const ScanService();

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
            await _handleBarcode(result.barcode!);
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
    await _mockScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
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
              label: '模拟扫描',
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
      _status = '正在检查/解压 pda.zip...';
    });

    BuildContext? dialogContext;
    final progress = ValueNotifier<double?>(null);
    final progressText = ValueNotifier<String>('正在检查 pda.zip...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return _ProgressDialog(
          messageListenable: progressText,
          progressListenable: progress,
        );
      },
    );

    OperationResult? opResult;
    try {
      final checkResult = await _scanService
          .checkZipExists()
          .timeout(const Duration(seconds: 10));
      opResult = checkResult.$2;
      _applyResult(opResult, showSnack: false);
      if (!checkResult.$1) {
        _applyResult(opResult);
        return;
      }

      progress.value = 0;
      progressText.value = '正在解压 pda.zip...';

      opResult = await _scanService.extractZip(
        onProgress: (value, fileName) {
          progress.value = value;
          progressText.value = '解压中: $fileName';
        },
      );
      _applyResult(opResult);
    } on TimeoutException catch (e) {
      final msg = '检查超时：${e.message ?? ''}';
      opResult = OperationResult(status: msg, snack: msg);
      LogUtil.e('[ZipCheck] 检查超时: $msg');
      _applyResult(opResult);
    } catch (e) {
      final msg = '检查失败：$e';
      opResult = OperationResult(status: msg, snack: msg);
      LogUtil.e('[ZipCheck] 失败: $e');
      _applyResult(opResult);
    } finally {
      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }
      if (mounted) {
        setState(() {
          _checkingZip = false;
        });
      }
      LogUtil.i('[ZipCheck] 完成: ${opResult?.status ?? '未知结果'}');
    }
  }

  Future<void> _mockScan() async {
    const mockBarcode = 'demo_file.txt';
    LogUtil.i('[MockScan] 模拟扫码: $mockBarcode');
    _applyResult(
      const OperationResult(
        status: '模拟扫码中: demo_file.txt',
        snack: '模拟扫码',
      ),
      showSnack: false,
    );
    await _handleBarcode(mockBarcode);
  }

  Future<void> _handleBarcode(String barcode) async {
    try {
      final result = await _scanService.handleBarcode(barcode);
      _applyResult(result);
    } catch (e, st) {
      final msg = '处理条码失败：$e';
      LogUtil.e('[Scan] 处理条码异常: $e\n$st');
      _applyResult(OperationResult(status: msg, snack: msg));
    }
  }

  void _applyResult(OperationResult result, {bool showSnack = true}) {
    if (mounted) {
      setState(() {
        _status = result.status;
      });
      if (showSnack) {
        _showSnack(result.snack);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({
    required this.messageListenable,
    required this.progressListenable,
  });

  final ValueListenable<String> messageListenable;
  final ValueListenable<double?> progressListenable;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: ValueListenableBuilder<double?>(
        valueListenable: progressListenable,
        builder: (context, value, _) {
          return ValueListenableBuilder<String>(
            valueListenable: messageListenable,
            builder: (context, message, __) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(message)),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
