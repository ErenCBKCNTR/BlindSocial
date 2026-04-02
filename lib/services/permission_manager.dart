import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  static Future<bool> requestInitialPermissions(BuildContext context) async {
    final permissions = <Permission>[
      Permission.notification,
      Permission.microphone,
    ];

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        permissions.add(Permission.audio);
      } else {
        permissions.add(Permission.storage);
      }
    } else {
      permissions.add(Permission.storage);
    }

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool isAnyDenied = false;
    bool isAnyPermanentlyDenied = false;

    statuses.forEach((permission, status) {
      if (status.isDenied) {
        isAnyDenied = true;
      }
      if (status.isPermanentlyDenied) {
        isAnyPermanentlyDenied = true;
      }
    });

    if (isAnyPermanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('İzin Gerekli'),
            content: const Text(
                'Uygulamanın düzgün çalışabilmesi için ayarlardan gerekli izinleri vermelisiniz.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Ayarlara Git'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    if (isAnyDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Uygulama özelliklerini kullanabilmek için izinlere ihtiyacımız var',
            ),
          ),
        );
      }
      return false;
    }

    return true;
  }

  static Future<void> requestNotificationPermission(BuildContext context) async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  static Future<bool> requestBsBibPermissions(BuildContext context) async {
    final permissions = [
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.bluetoothConnect,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool isAnyDenied = false;
    bool isAnyPermanentlyDenied = false;

    statuses.forEach((permission, status) {
      if (status.isDenied) {
        isAnyDenied = true;
      }
      if (status.isPermanentlyDenied) {
        isAnyPermanentlyDenied = true;
      }
    });

    if (isAnyPermanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('İzin Gerekli'),
            content: const Text(
                'Bu özelliği kullanabilmek için ayarlardan gerekli izinleri vermelisiniz.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Ayarlara Git'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    if (isAnyDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu özelliği kullanabilmek için izne ihtiyacımız var',
            ),
          ),
        );
      }
      return false;
    }

    return true;
  }
}
