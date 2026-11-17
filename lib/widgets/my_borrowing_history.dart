import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MyBorrowingHistory extends StatefulWidget {
  const MyBorrowingHistory({super.key, required this.records});
  final List<Map<String, dynamic>> records;

  @override
  State<MyBorrowingHistory> createState() => _MyBorrowingHistoryState();
}

class _MyBorrowingHistoryState extends State<MyBorrowingHistory> {
  @override
  Widget build(BuildContext context) {
    final records = widget.records.take(5).toList();

    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text('Belum ada riwayat peminjaman.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: records.map((record) {
        final status = (record['status'] ?? 'pending').toString();
        final title = (record['item_name'] ?? 'Alat').toString();
        final date = _asDate(
          record['borrow_date'] ?? record['request_date'] ?? record['created_at'],
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF1769AA)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Tanggal: ${_format(date)}'),
            trailing: _chip(status),
          ),
        );
      }).toList(),
    );
  }

  Widget _chip(String status) {
    final color = switch (status) {
      'active' => Colors.orange,
      'returned' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.blue,
    };
    final text = switch (status) {
      'active' => 'Dipinjam',
      'returned' => 'Dikembalikan',
      'rejected' => 'Ditolak',
      _ => 'Menunggu',
    };
    return Chip(
      label: Text(text, style: TextStyle(color: color, fontSize: 11)),
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: .1),
      visualDensity: VisualDensity.compact,
    );
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _format(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
