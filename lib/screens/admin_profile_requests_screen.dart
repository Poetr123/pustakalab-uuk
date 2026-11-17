import 'package:flutter/material.dart';

import '../services/borrowing_service.dart';

class AdminProfileRequestsScreen extends StatefulWidget {
  const AdminProfileRequestsScreen({super.key});

  @override
  State<AdminProfileRequestsScreen> createState() => _AdminProfileRequestsScreenState();
}

class _AdminProfileRequestsScreenState extends State<AdminProfileRequestsScreen> {
  final _service = BorrowingService();
  final Set<String> _processing = {};
  late final Stream<List<Map<String, dynamic>>> _requests =
      _service.streamPendingProfileRequests();

  void _message(String value) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _process(Map<String, dynamic> request, {required bool approve}) async {
    final id = (request['document_id'] ?? '').toString();
    if (id.isEmpty || _processing.contains(id)) return;
    setState(() => _processing.add(id));
    try {
      if (approve) {
        await _service.approveProfileUpdateRequest(id);
      } else {
        await _service.rejectRequest(id, note: 'Ditolak oleh admin.');
      }
      if (mounted) _message(approve ? 'Perubahan profil disetujui.' : 'Permintaan profil ditolak.');
    } catch (error) {
      if (mounted) _message('Gagal memproses permintaan: $error');
    } finally {
      if (mounted) setState(() => _processing.remove(id));
    }
  }

  Widget _row(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          SizedBox(width: 145, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Expanded(child: Text((value ?? '-').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Perubahan profil pengguna', style: TextStyle(fontWeight: FontWeight.bold))),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _requests,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Gagal memuat permintaan: ${snapshot.error}'));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) return const Center(child: Text('Tidak ada perubahan profil yang menunggu persetujuan.'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = requests[index];
                final id = (request['document_id'] ?? '').toString();
                final busy = _processing.contains(id);
                return Card(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.person_outline, color: Color(0xFF1769AA)),
                      const SizedBox(width: 9),
                      const Expanded(child: Text('Permintaan perubahan profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      const Chip(label: Text('Menunggu')),
                    ]),
                    const SizedBox(height: 10),
                    _row('Pengguna', request['current_name']),
                    _row('Kelas saat ini', request['current_class']),
                    _row('Nama baru', request['requested_name']),
                    _row('Kelas baru', request['requested_class']),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _process(request, approve: false),
                        icon: const Icon(Icons.close), label: const Text('Tolak'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton.icon(
                        onPressed: busy ? null : () => _process(request, approve: true),
                        icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                        label: const Text('Setujui'),
                      )),
                    ]),
                  ]),
                ));
              },
            );
          },
        ),
      );
}
