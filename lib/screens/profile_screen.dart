import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../services/borrowing_service.dart';
import '../widgets/app_image.dart';
import '../widgets/image_source_field.dart';
import '../widgets/my_borrowing_history.dart';
import 'admin_panel_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onLogout});
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _borrowing = BorrowingService();
  final _adminService = AdminService();
  late final _profileStream = _auth.getUserData();
  late final _historyStream = _borrowing.streamMyBorrowings();

  void _message(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editPhoto(String currentUrl) async {
    final controller = TextEditingController(text: currentUrl);
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Foto profil'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: ImageSourceField(
                controller: controller,
                label: 'URL foto (opsional)',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.clear();
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Hapus foto'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
      if (saved != true || !mounted) return;
      final user = _auth.currentUser;
      if (user == null) return;
      await user.reload();
      await _profileRef(user.uid).update({
        'foto': controller.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      _message(
        controller.text.trim().isEmpty
            ? 'Foto profil dihapus.'
            : 'Foto profil diperbarui.',
      );
    } catch (error) {
      _message('Gagal memperbarui foto: $error');
    } finally {
      controller.dispose();
    }
  }

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> _requestProfileChanges(String name, String kelas) async {
    await _borrowing.submitProfileChangeRequest(
      requestedName: name,
      requestedClass: kelas,
    );
  }

  Future<void> _editProfile(
    String name,
    String kelas, {
    required bool isAdmin,
  }) async {
    final nameController = TextEditingController(text: name);
    final classController = TextEditingController(text: kelas);
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            isAdmin ? 'Edit profil admin' : 'Ajukan perubahan profil',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama lengkap'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: classController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Kelas'),
              ),
              const SizedBox(height: 8),
              Text(
                isAdmin
                    ? 'Perubahan profil admin langsung diterapkan.'
                    : 'Perubahan nama dan kelas akan diterapkan setelah disetujui admin.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isAdmin ? 'Simpan langsung' : 'Kirim permintaan'),
            ),
          ],
        ),
      );
      if (submitted != true || !mounted) return;
      if (nameController.text.trim().isEmpty ||
          classController.text.trim().isEmpty) {
        _message('Nama dan kelas wajib diisi.');
        return;
      }
      if (isAdmin) {
        final uid = _auth.currentUser?.uid;
        if (uid == null) throw Exception('Silakan login terlebih dahulu.');
        await _adminService.updateUserProfile(
          uid: uid,
          name: nameController.text,
          kelas: classController.text,
        );
        _message('Profil admin berhasil diperbarui.');
      } else {
        await _requestProfileChanges(nameController.text, classController.text);
        _message(
          'Permintaan perubahan profil dikirim. Menunggu persetujuan admin.',
        );
      }
    } catch (error) {
      _message('Gagal mengirim permintaan: $error');
    } finally {
      nameController.dispose();
      classController.dispose();
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    try {
      final submit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ganti password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password saat ini',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password baru',
                    helperText: 'Minimal 6 karakter',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi password baru',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
      if (submit != true || !mounted) return;
      if (current.text.isEmpty || next.text.isEmpty || confirm.text.isEmpty) {
        _message('Semua bagian password wajib diisi.');
        return;
      }
      if (next.text.length < 6 || next.text != confirm.text) {
        _message(
          next.text.length < 6
              ? 'Password baru minimal 6 karakter.'
              : 'Konfirmasi password tidak sama.',
        );
        return;
      }
      final error = await _auth.changePassword(
        currentPassword: current.text,
        newPassword: next.text,
      );
      _message(error ?? 'Password berhasil diperbarui.');
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _profileStream,
    builder: (context, profileSnapshot) {
      if (profileSnapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (profileSnapshot.hasError)
        return Center(
          child: Text('Gagal memuat profil: ${profileSnapshot.error}'),
        );
      final user = profileSnapshot.data?.data();
      if (user == null)
        return const Center(child: Text('Data profil tidak ditemukan.'));
      final name = (user['name'] ?? 'Pengguna').toString();
      final kelas = (user['kelas'] ?? '').toString();
      final email = (user['email'] ?? '').toString();
      final foto = (user['foto'] ?? '').toString();
      final isAdmin = user['role'] == 'admin';

      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Profil',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Stack(
                children: [
                  ClipOval(child: AppImage(url: foto, width: 104, height: 104)),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: 'Ubah foto',
                      onPressed: () => _editPhoto(foto),
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Center(
              child: Text(
                isAdmin ? 'Administrator' : 'Siswa',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 24),
            _tile(Icons.email_outlined, 'Email', email),
            const SizedBox(height: 8),
            _tile(Icons.school_outlined, 'Kelas', kelas),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF1769AA),
                ),
                title: Text(
                  isAdmin
                      ? 'Edit nama / kelas'
                      : 'Ajukan perubahan nama / kelas',
                ),
                subtitle: Text(
                  isAdmin ? 'Ubah nama' : 'Perubahan harus disetujui admin',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editProfile(name, kelas, isAdmin: isAdmin),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF1769AA),
                ),
                title: const Text('Ganti password'),
                subtitle: const Text('Perbarui password akunmu'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changePassword,
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Color(0xFF1769AA),
                  ),
                  title: const Text('Panel admin'),
                  subtitle: const Text('Kelola permintaan dan pengguna'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            const Text(
              'Riwayat peminjaman saya',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _historyStream,
              builder: (context, historySnapshot) {
                if (historySnapshot.hasError)
                  return Text('Gagal memuat riwayat: ${historySnapshot.error}');
                if (historySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return MyBorrowingHistory(
                  records: historySnapshot.data ?? const [],
                );
              },
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _tile(IconData icon, String label, String value) => Card(
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF1769AA)),
      title: Text(label, style: const TextStyle(color: Colors.black54)),
      subtitle: Text(
        value.isEmpty ? '-' : value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
