import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

enum ToastType { success, failure, warning, help }

class ToastMessage {
  static void show({required BuildContext context, required String message, required ToastType type}) {
    ToastificationType toastType;
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case ToastType.success:
        toastType = ToastificationType.success;

        backgroundColor = ColorTheme.success;
        icon = Icons.check_circle_outline;
        break;
      case ToastType.failure:
        toastType = ToastificationType.error;
        backgroundColor = ColorTheme.error;
        icon = Icons.error_outline;
        break;
      case ToastType.warning:
        toastType = ToastificationType.warning;
        backgroundColor = ColorTheme.atention;
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.help:
        toastType = ToastificationType.info;
        backgroundColor = ColorTheme.info;
        icon = Icons.info_outline;
        break;
    }

    toastification.show(
      type: toastType,
      style: ToastificationStyle.flatColored,
      description: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: backgroundColor),
        overflow: TextOverflow.visible,
      ),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 4),
      icon: Icon(icon, color: backgroundColor),
      showProgressBar: true,
      progressBarTheme: ProgressIndicatorThemeData(color: backgroundColor, circularTrackColor: backgroundColor.withOpacity(0.2)),
    );
  }

  static ToastificationItem showProgress({
    required BuildContext context,
    required String title,
    required ValueNotifier<double> progressNotifier,
  }) {
    return toastification.show(
      type: ToastificationType.info,
      style: ToastificationStyle.flatColored,
      title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ColorTheme.info)),
      description: ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, value, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: value,
                backgroundColor: ColorTheme.info.withOpacity(0.2),
                color: ColorTheme.info,
              ),
              const SizedBox(height: 4),
              Text('${(value * 100).toInt()}% completado', style: TextStyle(color: ColorTheme.info)),
            ],
          );
        },
      ),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(minutes: 5), // Keep open until dismissed
      icon: const Icon(Icons.sync, color: ColorTheme.info),
      showProgressBar: false,
    );
  }

  static void dismiss(ToastificationItem item) {
    toastification.dismiss(item);
  }
}

class ColorTheme {
  //* Colores de alertas
  static const Color success = Color(0xFF00B69B);
  static const Color atention = Color(0xFFFFA756);
  static const Color error = Color(0xFFEF3826);
  static const Color info = Color(0xFF5A8CFF);
}
