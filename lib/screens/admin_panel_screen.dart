import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import 'admin_requests_screen.dart';
import 'admin_profile_requests_screen.dart';
import 'admin_users_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _service = AdminService();
  bool _syncingNames = false;

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _syncNames() async {
    setState(() => _syncingNames = true);
    try {
      final result = await _service.rebuildNameRegistry();
      final count = (result['indexed'] as num?)?.toInt() ?? 0;
      final conflicts = (result['conflict_count'] as num?)?.toInt() ?? 0;
      final conflictRows = (result['conflicts'] as List?) ?? const [];
      final conflictNames = conflictRows
          .map((entry) => (entry as Map)['normalized_name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .take(4)
          .join(', ');
      if (mounted) {
        _message(conflicts == 0
            ? '$count nama berhasil disinkronkan. Pendaftaran nama unik sudah aktif.'
            : '$count akun disinkronkan. Ditemukan $conflicts kelompok nama duplikat${conflictNames.isEmpty ? '' : ': $conflictNames'}. Ajukan perubahan nama bagi akun yang bentrok.');
      }
    } catch (error) {
      if (mounted) {
        _message('Gagal menyinkronkan nama: $error');
      }
    } finally {
      if (mounted) setState(() => _syncingNames = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Panel admin', style: TextStyle(fontWeight: FontWeight.bold))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Administrasi PustakaLab', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Kelola pengajuan peminjaman, perubahan profil, dan akun siswa secara terpisah.'),
          const SizedBox(height: 18),
          _panelTile(
            icon: Icons.fact_check_outlined,
            title: 'Pengajuan peminjaman',
            subtitle: 'Setujui atau tolak permintaan peminjaman alat',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRequestsScreen())),
          ),
          const SizedBox(height: 10),
          _panelTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Perubahan profil pengguna',
            subtitle: 'Tinjau permintaan perubahan nama dan kelas dari siswa',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfileRequestsScreen())),
          ),
          const SizedBox(height: 10),
          _panelTile(
            icon: Icons.people_outline,
            title: 'Kelola pengguna',
            subtitle: 'Lihat dan aktifkan/nonaktifkan akun siswa',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined, color: Color(0xFF1769AA)),
              title: const Text('Sinkronkan daftar nama unik'),
              subtitle: const Text('Jalankan sekali untuk mengunci nama akun lama agar tidak duplikat.'),
              trailing: _syncingNames
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _syncingNames ? null : _syncNames,
            ),
          ),
        ]),
      );

  Widget _panelTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) =>
      Card(child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1769AA)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ));
}
