import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminPanelRoomDetails extends StatefulWidget {
  final Map<String, dynamic> room;
  final DocumentReference roomRef;

  const AdminPanelRoomDetails({
    super.key,
    required this.room,
    required this.roomRef,
  });

  @override
  State<AdminPanelRoomDetails> createState() => _AdminPanelRoomDetailsState();
}

class _AdminPanelRoomDetailsState extends State<AdminPanelRoomDetails> {
  late TextEditingController _nameController;
  late TextEditingController _passwordController;
  late TextEditingController _capacityController;
  late TextEditingController _ttlController;

  String _creatorName = "Yükleniyor...";
  String _creatorId = "Yükleniyor...";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room['name']);
    _passwordController = TextEditingController(
      text: widget.room['plainPassword'] ?? '',
    );
    _capacityController = TextEditingController(
      text: widget.room['maxCapacity']?.toString() ?? '10',
    );
    _ttlController = TextEditingController(
      text: widget.room['ttlPreference']?.toString() ?? '24h',
    );
    _fetchCreatorInfo();
  }

  Future<void> _fetchCreatorInfo() async {
    try {
      String creatorUid = widget.room['creatorId'] ?? '';
      if (creatorUid.isNotEmpty) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorUid)
            .get();
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          setState(() {
            _creatorName =
                "${userData['fullName'] ?? 'İsimsiz'} (${userData['username'] ?? 'Kullanıcı Adı Yok'})";
            _creatorId = "U${userData['numericId']}";
          });
        } else {
          setState(() {
            _creatorName = "Kullanıcı Bulunamadı";
            _creatorId = "Bilinmiyor";
          });
        }
      } else {
        setState(() {
          _creatorName = "Bilinmiyor";
          _creatorId = "Bilinmiyor";
        });
      }
    } catch (e) {
      setState(() {
        _creatorName = "Hata oluştu";
        _creatorId = "Hata oluştu";
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _capacityController.dispose();
    _ttlController.dispose();
    super.dispose();
  }

  Future<void> _updateRoom() async {
    try {
      int? capacity = int.tryParse(_capacityController.text);
      if (capacity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kapasite geçerli bir sayı olmalıdır.')),
        );
        return;
      }

      String? password = _passwordController.text.isEmpty
          ? null
          : _passwordController.text;

      await widget.roomRef.update({
        'name': _nameController.text.trim(),
        'plainPassword': password,
        'password': password, // User requested no encryption
        'maxCapacity': capacity,
        'ttlPreference': _ttlController.text.trim(),
        // NOTE: actual ttl logic is somewhat tied to ttlPreference format (e.g., '24h'), but keeping simple update here
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Oda güncellendi.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _deleteRoom() async {
    try {
      // Cascade delete messages subcollection (in chunks of 500)
      final messagesSnapshot = await widget.roomRef.collection('messages').get();
      final docs = messagesSnapshot.docs;

      for (int i = 0; i < docs.length; i += 500) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = docs.sublist(i, i + 500 > docs.length ? docs.length : i + 500);
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Cascade delete storage files
      if (widget.room['numericId'] != null) {
        final folderRef = FirebaseStorage.instance
            .ref()
            .child('recordings')
            .child(widget.room['numericId'].toString());
        try {
          final listResult = await folderRef.listAll();
          for (final item in listResult.items) {
            await item.delete();
          }
        } catch (e) {
          debugPrint('Error deleting storage files: $e');
        }
      }

      await widget.roomRef.delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Oda silindi.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Timestamp? createdAtTimestamp = widget.room['createdAt'] as Timestamp?;
    String createdAt = createdAtTimestamp != null
        ? "${createdAtTimestamp.toDate().day}/${createdAtTimestamp.toDate().month}/${createdAtTimestamp.toDate().year} ${createdAtTimestamp.toDate().hour}:${createdAtTimestamp.toDate().minute}"
        : "Bilinmiyor";

    return Scaffold(
      appBar: AppBar(
        title: Text('Oda Detayları - R${widget.room['numericId']}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kuruluş Tarihi: $createdAt',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            Text(
              'Kurucu: $_creatorId - $_creatorName',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const Divider(height: 30, thickness: 2),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Oda İsmi'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Şifre'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _capacityController,
              decoration: const InputDecoration(labelText: 'Kapasite'),
              keyboardType: TextInputType.number,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ttlController,
              decoration: const InputDecoration(
                labelText: 'Geçerlilik Süresi (Örn: 24h, 3d)',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _updateRoom,
                  child: Text(
                    'Kaydet',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(
                          context,
                        ).scaffoldBackgroundColor,
                        title: Text(
                          'Odayı Sil',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        content: Text(
                          'Odayı silmek istediğinize emin misiniz?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Vazgeç'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteRoom();
                            },
                            child: const Text('SİL'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Odayı Sil',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
