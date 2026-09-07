import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ToastUtil {
  static void show(
    BuildContext context,
    String message, {
    ToastificationType type = ToastificationType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      title: Text(message),
      autoCloseDuration: duration,
      alignment: Alignment.bottomCenter,
      animationDuration: const Duration(milliseconds: 200),
      showProgressBar: false,
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      dragToClose: true,
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message, type: ToastificationType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message, type: ToastificationType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message, type: ToastificationType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message, type: ToastificationType.info);
  }
}
