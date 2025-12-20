import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Duration throttleDuration;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.throttleDuration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_ThrottleController>(
      create: (_) => _ThrottleController(),
      child: Consumer<_ThrottleController>(
        builder: (context, controller, _) {
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: controller.isThrottled
                ? null
                : () => controller.handlePress(
                      duration: throttleDuration,
                      onPressed: onPressed,
                    ),
            child: Text(
              label,
              style: AppTextStyles.button,
            ),
          );
        },
      ),
    );
  }
}

class _ThrottleController extends ChangeNotifier {
  bool _isThrottled = false;

  bool get isThrottled => _isThrottled;

  void handlePress({
    required Duration duration,
    required VoidCallback onPressed,
  }) {
    if (_isThrottled) return;

    _isThrottled = true;
    notifyListeners();
    onPressed();

    Future.delayed(duration, () {
      if (!_isThrottled) return;

      _isThrottled = false;
      notifyListeners();
    });
  }
}
