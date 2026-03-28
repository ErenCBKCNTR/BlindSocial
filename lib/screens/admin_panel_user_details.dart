import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelUserDetails extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminPanelUserDetails({super.key, required this.user});

  @override
  State<AdminPanelUserDetails> createState() => _AdminPanelUserDetailsState();
}

class _AdminPanelUserDetailsState extends State<AdminPanelUserDetails> {
  late int _roleId;

  @override
  void initState() {
    super.initState();
    _roleId = widget.user['role_id'] as int? ?? 2; // Default to user (2)
  }

  Future<void> _updateUserRole() async {
    try {
      final query = await FirebaseFirestore.instance.collection('users').where('numericId', isEqualTo: widget.user['numericId']).limit(1).get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({'role_id': _roleId});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı yetkisi güncellendi.')));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı bulunamadı.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _deleteUser() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Üyeyi Sil', style: TextStyle(color: Colors.red)),
        content: const Text('Bu üyeyi kalıcı olarak silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    ) ?? false;

    if (confirm) {
      try {
        final query = await FirebaseFirestore.instance.collection('users').where('numericId', isEqualTo: widget.user['numericId']).limit(1).get();
        if (query.docs.isNotEmpty) {
          await query.docs.first.reference.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üye başarıyla silindi.')));
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Timestamp? birthTimestamp = widget.user['birthDate'] as Timestamp?;
    String birthDate = birthTimestamp != null
        ? "${birthTimestamp.toDate().day}/${birthTimestamp.toDate().month}/${birthTimestamp.toDate().year}"
        : "Bilinmiyor";

    Timestamp? createdAtTimestamp = widget.user['createdAt'] as Timestamp?;
    String createdAt = createdAtTimestamp != null
        ? "${createdAtTimestamp.toDate().day}/${createdAtTimestamp.toDate().month}/${createdAtTimestamp.toDate().year}"
        : "Bilinmiyor";

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user['username'] ?? 'Bilinmiyor'} Detayları'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: U${widget.user['numericId'] ?? 'Bilinmiyor'}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Kullanıcı Adı: ${widget.user['username'] ?? 'Bilinmiyor'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 10),
            Text('İsim Soyisim: ${widget.user['fullName'] ?? 'Bilinmiyor'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 10),
            Text('E-posta: ${widget.user['email'] ?? 'Bilinmiyor'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 10),
            Text('Doğum Tarihi: $birthDate', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 10),
            Text('Kayıt Tarihi: $createdAt', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 30),
            Text('Kullanıcı Yetkisi', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _roleId,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[800],
              ),
              dropdownColor: Colors.grey[900],
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              items: const [
                DropdownMenuItem(value: 0, child: Text('0 - Sistem Yöneticisi')),
                DropdownMenuItem(value: 1, child: Text('1 - Teknik Ekip')),
                DropdownMenuItem(value: 2, child: Text('2 - Kullanıcı')),
              ],
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _roleId = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                onPressed: _updateUserRole,
                child: Text('Yetkiyi Güncelle', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                onPressed: _deleteUser,
                child: Text('Üyeyi Sil', style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
