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
      context: context,
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
}

class ColorTheme {
  //* Colores de alertas
  static const Color success = Color(0xFF00B69B);
  static const Color atention = Color(0xFFFFA756);
  static const Color error = Color(0xFFEF3826);
  static const Color info = Color(0xFF5A8CFF);
}
