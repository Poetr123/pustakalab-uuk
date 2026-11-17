import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/borrowing_service.dart';

class BorrowingHistoryScreen extends StatefulWidget {
  const BorrowingHistoryScreen({super.key});

  @override
  State<BorrowingHistoryScreen> createState() => _BorrowingHistoryScreenState();
}

class _BorrowingHistoryScreenState extends State<BorrowingHistoryScreen> {
  static const int _pageSize = 5;
  final _service = BorrowingService();
  final _auth = AuthService();
  final Set<String> _processing = {};
  late final Stream<List<Map<String, dynamic>>> _historyStream = _service
      .streamAllBorrowings();
  int _page = 0;

  Future<void> _return(
    Map<String, dynamic> record, {
    required bool isAdmin,
  }) async {
    final id = (record['document_id'] ?? record['borrow_id'] ?? '').toString();
    final itemId = (record['item_id'] ?? '').toString();
    if (id.isEmpty || itemId.isEmpty || _processing.contains(id)) {
      return;
    }

    setState(() => _processing.add(id));
    try {
      if (isAdmin) {
        await _service.adminReturnItem(itemId: itemId, borrowingId: id);
      } else {
        await _service.returnItem(itemId: itemId, borrowingId: id);
      }
      if (mounted) {
        _message(
          isAdmin
              ? 'Status alat berhasil dikembalikan oleh admin.'
              : 'Alat berhasil dikembalikan.',
        );
      }
    } catch (error) {
      if (mounted) {
        _message('Gagal mengembalikan alat: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _processing.remove(id));
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _runLegacyMigration();
  }

  Future<void> _runLegacyMigration() async {
    try {
      final count = await _service.migrateLegacyBorrowingsToRootIfAdmin();
      if (count > 0 && mounted) {
        _message('$count riwayat lama berhasil disinkronkan.');
      }
    } catch (error) {
      // The page remains usable even if the optional legacy migration cannot run.
      debugPrint('Legacy history migration: $error');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _auth.getUserData(),
    builder: (context, profileSnapshot) {
      final isAdmin = profileSnapshot.data?.data()?['role'] == 'admin';
      final uid = FirebaseAuth.instance.currentUser?.uid;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Riwayat peminjaman',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _historyStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _error('Gagal memuat riwayat: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = snapshot.data ?? [];
            if (records.isEmpty) {
              return const Center(child: Text('Belum ada riwayat peminjaman.'));
            }
            final pageCount = (records.length / _pageSize).ceil();
            final safePage = _page.clamp(0, pageCount - 1);
            final start = safePage * _pageSize;
            final visible = records.skip(start).take(_pageSize).toList();

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final record = visible[index];
                      final id = (record['document_id'] ?? '').toString();
                      final ownerUid =
                          (record['owner_uid'] ?? record['borrower_uid'] ?? '')
                              .toString();
                      final status = (record['status'] ?? 'active').toString();
                      final active = status == 'active';
                      final dueAt = _date(record['due_at']);
                      final overdue =
                          active &&
                          dueAt != null &&
                          dueAt.isBefore(DateTime.now());
                      final ownRecord = ownerUid == uid;
                      final canReturn = active && (ownRecord || isAdmin);
                      final busy = _processing.contains(id);

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Color(0xFF1769AA),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      (record['item_name'] ?? 'Alat')
                                          .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  _statusChip(status, overdue),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _detail(
                                'Peminjam',
                                (record['borrower_name'] ?? '-').toString(),
                              ),
                              if ((record['borrower_class'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                _detail(
                                  'Kelas',
                                  record['borrower_class'].toString(),
                                ),
                              _detail(
                                'Kode alat',
                                (record['item_code'] ?? '-').toString(),
                              ),
                              _detail(
                                'Tanggal pinjam',
                                _format(_date(record['borrow_date'])),
                              ),
                              if (record['duration_days'] is num)
                                _detail(
                                  'Durasi',
                                  '${record['duration_days']} hari',
                                ),
                              _detail('Batas pengembalian', _format(dueAt)),
                              if (_date(record['return_date']) != null)
                                _detail(
                                  'Tanggal kembali',
                                  _format(_date(record['return_date'])),
                                ),
                              if (canReturn) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonalIcon(
                                    onPressed: busy
                                        ? null
                                        : () => _return(
                                            record,
                                            isAdmin: isAdmin && !ownRecord,
                                          ),
                                    icon: busy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.assignment_return_outlined,
                                          ),
                                    label: Text(
                                      isAdmin && !ownRecord
                                          ? 'Tandai dikembalikan'
                                          : 'Kembalikan alat',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: safePage > 0
                            ? () => setState(() => _page--)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Sebelumnya'),
                      ),
                      const Spacer(),
                      Text('Halaman ${safePage + 1} dari $pageCount'),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: safePage + 1 < pageCount
                            ? () => setState(() => _page++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Berikutnya'),
                        iconAlignment: IconAlignment.end,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  Widget _error(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  Widget _statusChip(String status, bool overdue) {
    final isReturned = status == 'returned';
    final color = isReturned
        ? Colors.green
        : overdue
        ? Colors.red
        : status == 'active'
        ? Colors.orange
        : Colors.blueGrey;
    final label = isReturned
        ? 'Dikembalikan'
        : overdue
        ? 'Terlambat'
        : status == 'active'
        ? 'Dipinjam'
        : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        SizedBox(
          width: 145,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _format(DateTime? value) {
    if (value == null) return '-';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }
}
