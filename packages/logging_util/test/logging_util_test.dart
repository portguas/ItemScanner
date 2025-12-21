import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging_util/logging_util.dart';

void main() {
  test('LogUtil errorReporter 被触发', () async {
    final completer = Completer<void>();
    StackTrace? captured;

    LogUtil.init(
      errorReporter: (message, error, stackTrace) async {
        captured = stackTrace;
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    LogUtil.e('boom', StackTrace.current);
    await completer.future.timeout(const Duration(seconds: 1));

    expect(captured, isNotNull);
  });
}
