import 'package:flutter/material.dart';

import '../models/item_model.dart';
import 'app_image.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    this.compact = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAdminReturn,
  });

  final ItemModel item;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAdminReturn;

  bool get _isAvailable => item.status == 'Available';
  bool get _isOverdue => !_isAvailable && item.dueAt != null && item.dueAt!.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) => compact ? _compact() : _list();

  Widget _compact() => SizedBox(
        width: 174,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppImage(url: item.image, width: double.infinity, height: 100),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _statusLabel(),
                  if (!_isAvailable && item.borrowerName.isNotEmpty)
                    Text('Peminjam: ${item.borrowerName}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _list() => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(12),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: AppImage(url: item.image, width: 62, height: 62),
          ),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item.category} • ${item.code}'),
              const SizedBox(height: 4),
              _statusLabel(),
              if (!_isAvailable && item.borrowerName.isNotEmpty)
                Text('Peminjam: ${item.borrowerName}', style: const TextStyle(fontSize: 12)),
            ]),
          ),
          trailing: (onEdit != null || onDelete != null || onAdminReturn != null)
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                    if (value == 'return') onAdminReturn?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    if (onAdminReturn != null) const PopupMenuItem(value: 'return', child: Text('Tandai dikembalikan')),
                  ],
                )
              : null,
        ),
      );

  Widget _statusLabel() {
    final color = _isAvailable ? Colors.green.shade700 : _isOverdue ? Colors.red.shade700 : Colors.orange.shade800;
    final label = _isAvailable ? 'Tersedia' : _isOverdue ? 'Terlambat' : 'Dipinjam';
    return Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color));
  }
}
