// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:item_scanner/main.dart';

void main() {
  testWidgets('初始页面显示准备状态与提示文案', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('准备'), findsOneWidget);
    expect(find.text('暂无数据，请扫描'), findsOneWidget);
  });
}
