import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging_util/logging_util.dart';
import 'package:path/path.dart' as p;
import 'package:ui_design_system/ui_design_system.dart';
import 'package:provider/provider.dart';
import 'services/scan_service.dart';
import 'utils/app_directories.dart';
import 'state/home_state.dart';
import 'services/scanner_initialization_service.dart';

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

  // 启动应用后自动初始化扫描器（后台执行，不阻塞主线程）
  ScannerInitializationService.instance.initializeOnAppStart();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeState>(
          create: (_) => HomeState(),
        ),
      ],
      child: MaterialApp(
        title: '物品扫描',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(title: '物品扫描'),
      ),
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

  final ScanService _scanService = const ScanService();

  @override
  void initState() {
    super.initState();

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

          final barcode =
              (resultMap['barcode'] ?? resultMap['data'])?.toString().trim() ??
                  '';

          if (barcode.isNotEmpty) {
            await _handleBarcode(barcode);
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

  void _makeRequest() async {
    await _mockScan();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleLarge ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
    final subtitleStyle = textTheme.titleMedium ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final bodyStyle =
        textTheme.bodyMedium ?? const TextStyle(fontSize: 14, height: 1.4);
    final labelStyle = bodyStyle.copyWith(fontWeight: FontWeight.w600);
    final state = context.watch<HomeState>();
    final hasData = state.currentTitle != null ||
        state.scalarData.isNotEmpty ||
        state.tableData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: kDebugMode
            ? IconButton(
                onPressed:
                    state.checkingZip || state.loading ? null : _makeRequest,
                icon: const Icon(Icons.qr_code_2_outlined),
                tooltip: '模拟扫描',
              )
            : null,
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: state.checkingZip || state.loading ? null : _checkPdaZip,
            icon: const Icon(Icons.drive_folder_upload_outlined),
            tooltip: '选择并导入 zip',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (state.loading) ...[
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    state.status,
                    style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.currentTitle != null && hasData) ...[
              Text(
                state.currentTitle!,
                style: titleStyle,
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: hasData
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.scalarData.isNotEmpty)
                            _buildInfoCard(
                              labelStyle,
                              bodyStyle,
                              state.scalarData,
                            ),
                          ...state.tableData.entries.map(
                            (entry) => _buildTableCard(
                              entry.key,
                              entry.value,
                              subtitleStyle,
                              bodyStyle,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: Text(
                        '暂无数据，请扫描',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkPdaZip() async {
    final homeState = context.read<HomeState>();
    if (homeState.checkingZip) return;
    LogUtil.i('[ZipPick] 开始选择 zip');

    FilePickerResult? pickerResult;
    try {
      pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        allowMultiple: false,
        withReadStream: true,
        dialogTitle: '选择 zip 文件',
      );
    } catch (e, st) {
      final msg = '选择文件失败：$e';
      LogUtil.e('[ZipPick] 失败: $e\n$st');
      _applyResult(OperationResult(status: msg, snack: msg));
      return;
    }

    if (pickerResult == null || pickerResult.files.isEmpty) {
      LogUtil.i('[ZipPick] 用户取消选择');
      return;
    }

    final pickedFile = pickerResult.files.single;
    final isZip = (pickedFile.extension ?? '').toLowerCase() == 'zip';
    if (!isZip) {
      const msg = '请选择 zip 格式文件';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('我知道了'),
            ),
          ],
        ),
      );
      _applyResult(const OperationResult(status: msg, snack: msg), showSnack: false);
      return;
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('注意'),
        content: Text('将导入并解压 "${pickedFile.name}"，之前的文件将被清空，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      LogUtil.i('[ZipPick] 用户取消导入');
      return;
    }

    if (!mounted) return;

    // 清空当前显示
    homeState.clearDisplay();
    homeState
      ..setChecking(true)
      ..setStatus('正在导入：${pickedFile.name}');

    BuildContext? dialogContext;
    final progress = ValueNotifier<double?>(null);
    final progressText = ValueNotifier<String>('正在准备：${pickedFile.name}');
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
      opResult = await _scanService.importZipFile(
        pickedFile,
        onDeleteProgress: (value, fileName) {
          // 删除阶段仅提示，不展示进度条，避免与解压进度混淆
          progress.value = null;
          progressText.value = '清理旧目录: $fileName';
        },
        onExtractProgress: (value, fileName) {
          // 解压阶段单独计算
          progress.value = value;
          progressText.value = '解压中: $fileName';
        },
      );
      _applyResult(opResult);
    } catch (e, st) {
      final msg = '导入失败：$e';
      opResult = OperationResult(status: msg, snack: msg);
      LogUtil.e('[ZipPick] 导入失败: $e\n$st');
      _applyResult(opResult);
    } finally {
      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }
      homeState.setChecking(false);
      LogUtil.i('[ZipPick] 完成: ${opResult?.status ?? '未知结果'}');
    }
  }

  Future<void> _mockScan() async {
    const mockBarcode = 'OUT202512160001';
    try {
      await _ensureMockFile(mockBarcode);
      await _handleBarcode(mockBarcode);
    } catch (e, st) {
      final msg = '加载 mock 数据失败：$e';
      LogUtil.e('[MockScan] 失败: $e\n$st');
      _applyResult(OperationResult(status: msg, snack: msg));
    }
  }

  Future<void> _handleBarcode(String barcode) async {
    if (!mounted) return;
    final homeState = context.read<HomeState>();

    if (homeState.loading) {
      LogUtil.w('[Scan] 上一次条码仍在处理中，忽略: $barcode');
      return;
    }

    homeState
      ..setLoading(true)
      ..setStatus('正在处理：$barcode');

    try {
      final doc = await _scanService.loadDocument(barcode);
      if (doc == null) {
        final msg = '文件未找到或解析失败：$barcode';
        _applyResult(OperationResult(status: msg, snack: msg));
        return;
      }
      _showDocument(doc);
      _applyResult(
        OperationResult(
          status: '找到文件：$barcode',
          snack: '找到文件：$barcode',
        ),
        showSnack: false,
      );
      _showSnack('找到文件：$barcode');
    } catch (e, st) {
      final msg = '处理条码失败：$e';
      LogUtil.e('[Scan] 处理条码异常: $e\n$st');
      _applyResult(OperationResult(status: msg, snack: msg));
    } finally {
      if (mounted) {
        homeState.setLoading(false);
      }
    }
  }

  void _applyResult(OperationResult result, {bool showSnack = true}) {
    if (!mounted) return;
    context.read<HomeState>().setStatus(result.status);
    if (showSnack) {
      _showSnack(result.snack);
    }
  }

  void _showDocument(DocumentData doc) {
    if (!mounted) return;
    context.read<HomeState>().setDocument(doc);
  }

  Widget _buildInfoCard(
    TextStyle labelStyle,
    TextStyle valueStyle,
    Map<String, String> scalar,
  ) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: scalar.entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          e.key,
                          style: labelStyle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.value,
                          style: valueStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTableCard(
    String title,
    List<Map<String, dynamic>> rows,
    TextStyle titleStyle,
    TextStyle cellStyle,
  ) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final headers = rows.first.keys.toList();
    final scrollController = ScrollController();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: titleStyle,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${rows.length} 条',
                style: cellStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        children: [
          SizedBox(
            width: double.infinity,
            child: Scrollbar(
              thumbVisibility: true,
              controller: scrollController,
              child: SingleChildScrollView(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  headingRowHeight: 36,
                  dataRowHeight: 48,
                  columns: headers
                      .map(
                        (h) => DataColumn(
                          label: Text(
                            h,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: headers
                              .map(
                                (h) => DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 80,
                                      maxWidth: 220,
                                    ),
                                    child: Text(
                                      '${row[h] ?? ''}',
                                      style: cellStyle,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _ensureMockFile(String barcode) async {
    final extractDir = await AppDirectories.getPdaExtractDirectory();
    if (!await extractDir.exists()) {
      await extractDir.create(recursive: true);
    }
    final file = File(p.join(extractDir.path, '$barcode.json'));
    if (await file.exists()) return;

    final data = await rootBundle.loadString('assets/data/$barcode.json');
    await file.writeAsString(data);
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
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: value),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
