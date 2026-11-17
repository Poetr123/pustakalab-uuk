import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../widgets/app_image.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _service = AdminService();
  final _searchController = TextEditingController();
  String _query = '';
  final Set<String> _busy = {};
  late final Stream<List<Map<String, dynamic>>> _users = _service.streamUsers();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _editUser(Map<String, dynamic> user) async {
    final uid = (user['document_id'] ?? '').toString();
    final nameController = TextEditingController(text: (user['name'] ?? '').toString());
    final classController = TextEditingController(text: (user['kelas'] ?? '').toString());
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit profil pengguna'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama lengkap')),
            const SizedBox(height: 12),
            TextField(controller: classController, textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Kelas')),
            const SizedBox(height: 8),
            const Text('Perubahan oleh admin langsung disimpan tanpa persetujuan.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Simpan langsung')),
          ],
        ),
      );
      if (save != true || !mounted) return;
      setState(() => _busy.add(uid));
      await _service.updateUserProfile(
        uid: uid,
        name: nameController.text,
        kelas: classController.text,
      );
      if (mounted) _message('Profil pengguna berhasil diperbarui.');
    } catch (error) {
      if (mounted) _message('Gagal memperbarui profil: $error');
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
      nameController.dispose();
      classController.dispose();
    }
  }

  Future<void> _toggle(Map<String, dynamic> user, bool active) async {
    final uid = (user['document_id'] ?? '').toString();
    setState(() => _busy.add(uid));
    try {
      await _service.setUserActive(uid, active);
      if (mounted) _message(active ? 'Akun diaktifkan.' : 'Akun dinonaktifkan.');
    } catch (error) {
      if (mounted) _message('Gagal mengubah status akun: $error');
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kelola pengguna', style: TextStyle(fontWeight: FontWeight.bold))),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari nama, email, atau kelas'),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _users,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Gagal memuat pengguna: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final query = _query.trim().toLowerCase();
                final users = (snapshot.data ?? []).where((user) {
                  final text = '${user['name'] ?? ''} ${user['email'] ?? ''} ${user['kelas'] ?? ''}'.toLowerCase();
                  return text.contains(query);
                }).toList();
                if (users.isEmpty) return const Center(child: Text('Pengguna tidak ditemukan.'));
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final uid = (user['document_id'] ?? '').toString();
                    final active = user['active'] != false;
                    final isAdmin = user['role'] == 'admin';
                    final busy = _busy.contains(uid);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          ClipOval(child: AppImage(url: (user['foto'] ?? '').toString(), width: 48, height: 48)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text((user['name'] ?? 'Tanpa nama').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text((user['email'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            Text('${user['kelas'] ?? '-'} • ${isAdmin ? 'Admin' : 'User'} • ${active ? 'Aktif' : 'Nonaktif'}',
                                style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ])),
                          PopupMenuButton<String>(
                            enabled: !busy,
                            onSelected: (value) {
                              if (value == 'edit') _editUser(user);
                              if (value == 'toggle' && !isAdmin) _toggle(user, !active);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit profil langsung')),
                              if (!isAdmin)
                                PopupMenuItem(value: 'toggle', child: Text(active ? 'Nonaktifkan & bebaskan nama' : 'Aktifkan akun')),
                            ],
                          ),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}
