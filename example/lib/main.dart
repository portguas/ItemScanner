import 'package:flutter/material.dart';
import 'package:logging_util/logging_util.dart';
import 'package:service_network/service_network.dart';
import 'package:ui_design_system/ui_design_system.dart';

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
      title: 'CMP Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'CMP Example Home Page'),
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
  late final NetworkClient _networkClient;
  late final TodoRepository _todoRepository;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _networkClient = NetworkClient(
      config: NetworkConfig(
        baseUrl: 'https://api.example.com',
        tokenProvider: () async => 'demo_token',
        // 示例：本地桩返回，避免依赖真实服务。
        stubResolver: (req) {
          if (req.path == '/todos/1') {
            return const StubResponse(
              statusCode: 200,
              data: {
                'code': 200,
                'message': 'success',
                'data': {'id': 1, 'title': '示例待办'},
              },
            );
          }
          return null;
        },
      ),
    );
    _todoRepository = TodoRepository(_networkClient);
  }

  void _makeRequest() async {
    setState(() {
      _status = 'Loading...';
    });
    LogUtil.d('[UI] Button pressed');

    try {
      final todo = await _todoRepository.fetchTodo();
      setState(() {
        _status = 'Success: ${todo.title}';
      });
      LogUtil.i('[UI] Request successful');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      LogUtil.e('[UI] Request failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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

}

class TodoRepository {
  TodoRepository(this._client);

  final NetworkClient _client;

  Future<Todo> fetchTodo() {
    return _client.get<Todo>(
      '/todos/1',
      parser: (json) => Todo.fromJson(json as Map<String, dynamic>),
    );
  }
}

class Todo {
  final int id;
  final String title;

  Todo({
    required this.id,
    required this.title,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int,
      title: json['title'] as String,
    );
  }
}
