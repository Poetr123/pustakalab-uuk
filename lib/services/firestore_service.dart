import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/item_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore db;
  final FirebaseAuth auth;

  Stream<List<ItemModel>> getItems() => db.collection('items').snapshots().map((
    snapshot,
  ) {
    final items = snapshot.docs
        .map((doc) => ItemModel.fromMap(doc.data(), doc.id))
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  });

  Future<void> addItem(ItemModel item) async {
    await _requireAdmin();
    final ref = db.collection('items').doc();
    final category = await _canonicalCategory(item.category);
    await ref.set({
      ...item.toMap(),
      'category': category,
      'item_id': ref.id,
      'status': 'Available',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(String id, ItemModel item) async {
    await _requireAdmin();
    final ref = db.collection('items').doc(id);
    final category = await _canonicalCategory(item.category, excludeItemId: id);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('Alat tidak ditemukan.');
      if (snapshot.data()?['status'] != 'Available') {
        throw Exception('Alat yang sedang dipinjam tidak dapat diedit.');
      }
      transaction.update(ref, {
        'item_name': item.name,
        'category': category,
        'code': item.code,
        'image': item.image,
        'spesification': item.specification,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteItem(String id) async {
    await _requireAdmin();
    final ref = db.collection('items').doc(id);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      if (snapshot.data()?['status'] != 'Available') {
        throw Exception('Alat masih dipinjam dan tidak dapat dihapus.');
      }
      transaction.delete(ref);
    });
  }

  Future<String> _canonicalCategory(
    String input, {
    String? excludeItemId,
  }) async {
    final value = input.trim();
    final normalized = value.toLowerCase();
    if (normalized.isEmpty) return value;

    final snapshot = await db.collection('items').get();
    for (final doc in snapshot.docs) {
      if (doc.id == excludeItemId) continue;
      final existing = (doc.data()['category'] ?? '').toString().trim();
      if (existing.toLowerCase() == normalized) return existing;
    }
    return value;
  }

  Future<void> _requireAdmin() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');
    final profile = await db.collection('users').doc(user.uid).get();
    if (profile.data()?['role'] != 'admin')
      throw Exception('Fitur ini hanya untuk admin.');
  }
}
