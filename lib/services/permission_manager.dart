import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
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
