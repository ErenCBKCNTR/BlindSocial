import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/bs_bib_call_screen.dart';
import '../main.dart'; // import navigatorKey

class GlobalCallOverlay extends StatefulWidget {
  final Widget child;

  const GlobalCallOverlay({super.key, required this.child});

  @override
  State<GlobalCallOverlay> createState() => _GlobalCallOverlayState();
}

class _GlobalCallOverlayState extends State<GlobalCallOverlay> {
  StreamSubscription<QuerySnapshot>? _callSubscription;
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _checkRoleAndListen();
  }

  Future<void> _checkRoleAndListen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserUid = user.uid;
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final roleId = doc.data()?['role_id'] as int?;
          if (roleId == 0) {
            _listenToCalls();
          }
        }
      }
    } catch (e) {
      // Ignore errors if Firebase is not initialized (e.g. during testing)
    }
  }

  void _listenToCalls() {
    _callSubscription = FirebaseFirestore.instance
        .collection('bs_bib_calls')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          // Ignore if the admin is the one who created the call (shouldn't happen, but just in case)
          if (data['callerId'] != _currentUserUid) {
            _showCallOverlay(data);
          }
        }
      }
    });
  }

  void _showCallOverlay(Map<String, dynamic> data) {
    if (!mounted) return;

    String roomId = data['roomId'] ?? 'Bilinmiyor';
    String callerName = data['callerName'] ?? 'İsimsiz';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aktif bir çağrı isteği var. Kullanıcı: $callerName'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Katıl',
          onPressed: () {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => BSBibCallScreen(
                  roomId: roomId,
                  isAdmin: true,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
