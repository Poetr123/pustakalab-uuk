import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item_model.dart';
import '../services/borrowing_service.dart';
import '../widgets/app_image.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.item});
  final ItemModel item;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _service = BorrowingService();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _itemStream =
      FirebaseFirestore.instance.collection('items').doc(widget.item.id).snapshots();
  bool _submitting = false;

  Future<void> _submitRequest() async {
    if (_submitting) return;
    var duration = 7;
    final days = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajukan peminjaman'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Durasi yang diajukan'),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: duration,
              items: List.generate(BorrowingService.maxDurationDays, (i) => i + 1)
                  .map((day) => DropdownMenuItem(value: day, child: Text('$day hari'))).toList(),
              onChanged: (value) => setDialogState(() => duration = value ?? 7),
            ),
            const SizedBox(height: 8),
            const Text('Pengajuan akan menunggu persetujuan admin sebelum alat berstatus Dipinjam.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, duration), child: const Text('Kirim pengajuan')),
          ],
        ),
      ),
    );
    if (days == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      await _service.submitBorrowRequest(widget.item.id, durationDays: days);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan terkirim. Tunggu persetujuan admin.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengajukan peminjaman: $error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _itemStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Detail inventaris')),
              body: Center(child: Text('Gagal memuat detail alat: ${snapshot.error}')),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Detail inventaris')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(title: const Text('Detail inventaris')),
              body: const Center(child: Text('Alat tidak ditemukan atau sudah dihapus.')),
            );
          }

          final itemData = snapshot.data!.data()!;
          final item = ItemModel.fromMap(itemData, snapshot.data!.id);
          final borrowed = item.status == 'Borrowed';
          final pending = (itemData['pending_borrow_request_id'] ?? '')
              .toString()
              .isNotEmpty;
          return Scaffold(
            appBar: AppBar(title: const Text('Detail inventaris')),
            body: ListView(padding: const EdgeInsets.all(18), children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppImage(url: item.image, width: double.infinity, height: 220),
              ),
              const SizedBox(height: 18),
              Text(item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _detail('Kategori', item.category),
              _detail('Kode serial', item.code),
              _detail(
                'Status',
                borrowed
                    ? 'Dipinjam'
                    : pending
                        ? 'Menunggu persetujuan'
                        : 'Tersedia',
              ),
              _detail('Spesifikasi', item.specification.isEmpty ? '-' : item.specification),
              if (borrowed) ...[
                const Divider(height: 28),
                const Text('Informasi peminjaman', style: TextStyle(fontWeight: FontWeight.bold)),
                _detail('Nama peminjam', item.borrowerName.isEmpty ? '-' : item.borrowerName),
                _detail('Kelas', item.borrowerClass.isEmpty ? '-' : item.borrowerClass),
                _detail('Batas kembali', _format(item.dueAt)),
              ],
              const SizedBox(height: 24),
              if (!borrowed && !pending)
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submitRequest,
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined),
                    label: const Text('Ajukan peminjaman'),
                  ),
                )
              else
                Text(
                  pending
                      ? 'Alat ini sudah memiliki pengajuan dan sedang menunggu persetujuan admin.'
                      : 'Alat sedang dipinjam dan belum tersedia untuk pengajuan baru.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
            ]),
          );
        },
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  String _format(DateTime? value) => value == null
      ? '-'
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
