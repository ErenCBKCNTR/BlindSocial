import 'package:flutter/material.dart';

class CustomBottomSheet {
  /// Gösterilecek global ve taşma korumalı (overflow-proof) bottom sheet metodudur.
  /// İçerik varsayılan olarak SafeArea, SingleChildScrollView ve klavye padding'i ile sarmalanır.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    ShapeBorder? shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      shape: shape,
      builder: (context) {
        Widget content = Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(child: child),
        );

        if (useSafeArea) {
          content = SafeArea(child: content);
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: content,
        );
      },
    );
  }
}
