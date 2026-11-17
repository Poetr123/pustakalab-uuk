import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../services/auth_service.dart';
import '../services/borrowing_service.dart';
import '../services/firestore_service.dart';
import '../widgets/image_source_field.dart';
import '../widgets/item_card.dart';
import '../widgets/search_bar.dart';
import 'borrowing_history_screen.dart';
import 'item_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _borrowing = BorrowingService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final Stream<List<ItemModel>> _itemsStream = _firestore.getItems();
  late final Stream _userStream = _auth.getUserData();
  String _search = '';
  String _category = 'Semua';
  final Set<String> _returning = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requiredAlert(List<String> fields, BuildContext dialogContext) async {
    await showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Data belum lengkap'),
        content: Text('Bagian berikut wajib diisi:\n\n${fields.map((e) => '• $e').join('\n')}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti'))],
      ),
    );
  }

  Future<void> _showItemForm({ItemModel? item}) async {
    if (item != null && item.status != 'Available') {
      _message('Alat yang sedang dipinjam tidak dapat diedit.');
      return;
    }
    final name = TextEditingController(text: item?.name ?? '');
    final category = TextEditingController(text: item?.category ?? '');
    final code = TextEditingController(text: item?.code ?? '');
    final image = TextEditingController(text: item?.image ?? '');
    final specification = TextEditingController(text: item?.specification ?? '');
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item == null ? 'Tambah inventaris' : 'Edit inventaris'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _field(name, 'Nama alat *'),
                _field(category, 'Kategori *'),
                _field(code, 'Kode serial *'),
                ImageSourceField(controller: image),
                const SizedBox(height: 12),
                _field(specification, 'Spesifikasi', lines: 3),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final missing = <String>[];
                if (name.text.trim().isEmpty) missing.add('Nama alat');
                if (category.text.trim().isEmpty) missing.add('Kategori');
                if (code.text.trim().isEmpty) missing.add('Kode serial');
                if (missing.isNotEmpty) {
                  await _requiredAlert(missing, dialogContext);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
      if (saved != true || !mounted) return;
      final data = ItemModel(
        id: item?.id ?? '', name: name.text.trim(), category: category.text.trim(),
        code: code.text.trim(), status: 'Available', image: image.text.trim(),
        specification: specification.text.trim(),
      );
      if (item == null) {
        await _firestore.addItem(data);
      } else {
        await _firestore.updateItem(item.id, data);
      }
      _message(item == null ? 'Inventaris berhasil ditambahkan.' : 'Inventaris berhasil diperbarui.');
    } catch (error) {
      _message('Gagal menyimpan inventaris: $error');
    } finally {
      name.dispose(); category.dispose(); code.dispose(); image.dispose(); specification.dispose();
    }
  }

  Widget _field(TextEditingController controller, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          maxLines: lines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _delete(ItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus inventaris?'),
        content: Text('Data ${item.name} akan dihapus dari inventaris. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _firestore.deleteItem(item.id);
      _message('Inventaris berhasil dihapus.');
    } catch (error) {
      _message('Gagal menghapus inventaris: $error');
    }
  }

  Future<void> _adminReturn(ItemModel item) async {
    if (item.activeBorrowingId.isEmpty || _returning.contains(item.id)) {
      _message('Riwayat aktif alat ini tidak ditemukan.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tandai dikembalikan?'),
        content: Text('Konfirmasi bahwa ${item.name} sudah dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Konfirmasi')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _returning.add(item.id));
    try {
      await _borrowing.adminReturnItem(itemId: item.id, borrowingId: item.activeBorrowingId);
      _message('Status alat berhasil diubah menjadi Tersedia.');
    } catch (error) {
      _message('Gagal mengubah status: $error');
    } finally {
      if (mounted) setState(() => _returning.remove(item.id));
    }
  }

  void _openDetails(ItemModel item) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: _userStream,
        builder: (context, userSnapshot) {
          final isAdmin = userSnapshot.data?.data()?['role'] == 'admin';
          return Scaffold(
            appBar: AppBar(
              title: const Text('Inventaris', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  tooltip: 'Riwayat peminjaman', icon: const Icon(Icons.history),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BorrowingHistoryScreen())),
                ),
              ],
            ),
            body: StreamBuilder<List<ItemModel>>(
              stream: _itemsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Gagal memuat inventaris: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data ?? [];
                final categoryByKey = <String, String>{};
                for (final item in items) {
                  final value = item.category.trim();
                  if (value.isNotEmpty) {
                    categoryByKey.putIfAbsent(value.toLowerCase(), () => value);
                  }
                }
                final categories = categoryByKey.values.toList()..sort();
                final query = _search.toLowerCase().trim();
                final filtered = items.where((item) {
                  final matches = '${item.name} ${item.category} ${item.code}'.toLowerCase().contains(query);
                  return matches && (_category == 'Semua' || item.category.toLowerCase() == _category.toLowerCase());
                }).toList();
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: PustakaSearchBar(controller: _searchController, focusNode: _searchFocusNode,
                        onChanged: (value) => setState(() => _search = value)),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      scrollDirection: Axis.horizontal,
                      children: ['Semua', ...categories].map((value) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: Text(value), selected: _category == value,
                            onSelected: (_) => setState(() => _category = value)),
                      )).toList(),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text(items.isEmpty ? 'Belum ada inventaris.' : 'Alat tidak ditemukan.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final item = filtered[index];
                              return ItemCard(
                                item: item,
                                onTap: () => _openDetails(item),
                                onEdit: isAdmin && item.isAvailable ? () => _showItemForm(item: item) : null,
                                onDelete: isAdmin && item.isAvailable ? () => _delete(item) : null,
                                onAdminReturn: isAdmin && item.isBorrowed && item.activeBorrowingId.isNotEmpty
                                    ? () => _adminReturn(item) : null,
                              );
                            },
                          ),
                  ),
                ]);
              },
            ),
            floatingActionButton: isAdmin
                ? FloatingActionButton(onPressed: () => _showItemForm(), tooltip: 'Tambah inventaris', child: const Icon(Icons.add))
                : null,
          );
        },
      );
}
