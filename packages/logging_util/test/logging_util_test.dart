import 'package:flutter_test/flutter_test.dart';
import 'package:logging_util/logging_util.dart';

void main() {
  test('LogUtil errorReporter 被触发', () async {
    var reported = false;
    StackTrace? captured;

    LogUtil.init(
      errorReporter: (message, error, stackTrace) async {
        reported = true;
        captured = stackTrace;
      },
    );

    LogUtil.e('boom', StackTrace.current);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(reported, isTrue);
    expect(captured, isNotNull);
  });
}
