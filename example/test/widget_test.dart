// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('展示初始状态并发起网络请求', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Ready'), findsOneWidget);
    expect(find.textContaining('Success'), findsNothing);

    await tester.tap(find.text('Make Network Request'));
    await tester.pump(); // 先响应 setState: Loading...
    await tester.pumpAndSettle(); // 等待模拟的网络返回

    expect(find.textContaining('Success: 示例待办'), findsOneWidget);
  });
}
