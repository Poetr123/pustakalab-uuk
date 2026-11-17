import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'name_registry.dart';

class AdminService {
  AdminService({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore db;
  final FirebaseAuth auth;

  Stream<List<Map<String, dynamic>>> streamUsers() =>
      db.collection('users').snapshots().map((snapshot) {
        final users = snapshot.docs
            .map((doc) => {...doc.data(), 'document_id': doc.id})
            .toList();
        users.sort(
          (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
            (b['name'] ?? '').toString().toLowerCase(),
          ),
        );
        return users;
      });

  Future<void> setUserActive(String uid, bool active) async {
    await _requireAdmin();
    final currentUid = auth.currentUser?.uid;
    if (uid == currentUid) {
      throw Exception('Admin tidak dapat menonaktifkan akunnya sendiri.');
    }

    final userRef = db.collection('users').doc(uid);
    final userSnapshot = await userRef.get();
    if (!userSnapshot.exists) throw Exception('Pengguna tidak ditemukan.');
    final user = userSnapshot.data()!;
    if (user['role'] == 'admin') {
      throw Exception(
        'Akun admin lain tidak dapat dinonaktifkan dari menu ini.',
      );
    }
    final name = (user['name'] ?? '').toString().trim();
    final storedKey = (user['name_key'] ?? '').toString();
    final nameKey = storedKey.isNotEmpty
        ? storedKey
        : (name.isEmpty ? '' : NameRegistry.documentId(name));
    final nameRef = nameKey.isEmpty
        ? null
        : db.collection('user_names').doc(nameKey);
    final nameSnapshot = nameRef == null ? null : await nameRef.get();

    if (!active) {
      final activeLoans = await userRef
          .collection('borrowings')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      final borrowedItems = await db
          .collection('items')
          .where('borrower_uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (activeLoans.docs.isNotEmpty || borrowedItems.docs.isNotEmpty) {
        throw Exception(
          'Pengguna masih memiliki alat yang belum dikembalikan.',
        );
      }
      final batch = db.batch();
      batch.update(userRef, {
        'active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (nameRef != null &&
          nameSnapshot?.exists == true &&
          nameSnapshot?.data()?['uid'] == uid) {
        batch.delete(nameRef);
      }
      await batch.commit();
      return;
    }

    if (nameSnapshot?.exists == true && nameSnapshot?.data()?['uid'] != uid) {
      throw Exception(
        'Nama pengguna sudah dipakai akun lain. Ubah nama akun ini terlebih dahulu.',
      );
    }
    final batch = db.batch();
    batch.update(userRef, {
      'active': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
    if (name.isNotEmpty && nameRef != null) {
      batch.set(nameRef, {
        'uid': uid,
        'display_name': name,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String kelas,
  }) async {
    await _requireAdmin();
    final cleanName = name.trim();
    final cleanClass = kelas.trim();
    if (cleanName.isEmpty || cleanClass.isEmpty) {
      throw Exception('Nama dan kelas wajib diisi.');
    }

    final userRef = db.collection('users').doc(uid);
    final userSnapshot = await userRef.get();
    if (!userSnapshot.exists) throw Exception('Pengguna tidak ditemukan.');
    final oldData = userSnapshot.data()!;
    final oldName = (oldData['name'] ?? '').toString().trim();
    final oldKeyStored = (oldData['name_key'] ?? '').toString();
    final oldKey = oldKeyStored.isNotEmpty
        ? oldKeyStored
        : (oldName.isEmpty ? '' : NameRegistry.documentId(oldName));
    final newKey = NameRegistry.documentId(cleanName);
    final newNameRef = db.collection('user_names').doc(newKey);
    final oldNameRef = oldKey.isEmpty ? null : db.collection('user_names').doc(oldKey);
    final pendingProfileRequests = await db.collection('requests')
        .where('owner_uid', isEqualTo: uid)
        .where('request_type', isEqualTo: 'profile_update')
        .where('status', isEqualTo: 'pending')
        .get();

    await db.runTransaction((transaction) async {
      final currentUser = await transaction.get(userRef);
      if (!currentUser.exists) throw Exception('Pengguna tidak ditemukan.');
      final currentData = currentUser.data()!;
      final currentOldName = (currentData['name'] ?? '').toString().trim();
      final currentOldKeyStored = (currentData['name_key'] ?? '').toString();
      final currentOldKey = currentOldKeyStored.isNotEmpty
          ? currentOldKeyStored
          : (currentOldName.isEmpty ? '' : NameRegistry.documentId(currentOldName));
      if (currentOldKey != oldKey) {
        throw Exception('Profil berubah. Muat ulang daftar pengguna lalu coba lagi.');
      }

      final newNameSnapshot = newKey == oldKey ? null : await transaction.get(newNameRef);
      final oldNameSnapshot = oldNameRef == null || newKey == oldKey
          ? null
          : await transaction.get(oldNameRef);
      final pendingRequestSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final request in pendingProfileRequests.docs) {
        pendingRequestSnapshots.add(await transaction.get(request.reference));
      }
      if (newNameSnapshot?.exists == true && newNameSnapshot?.data()?['uid'] != uid) {
        throw Exception('Nama tersebut sudah digunakan pengguna lain.');
      }

      if (newKey != oldKey) {
        transaction.set(newNameRef, {
          'uid': uid,
          'display_name': cleanName,
          'updated_at': FieldValue.serverTimestamp(),
        });
        if (oldNameRef != null && oldNameSnapshot?.data()?['uid'] == uid) {
          transaction.delete(oldNameRef);
        }
      } else if (newKey.isNotEmpty) {
        transaction.set(newNameRef, {
          'uid': uid,
          'display_name': cleanName,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      for (final requestSnapshot in pendingRequestSnapshots) {
        if (requestSnapshot.exists && requestSnapshot.data()?['status'] == 'pending') {
          transaction.update(requestSnapshot.reference, {
            'status': 'cancelled',
            'review_note': 'Dibatalkan karena profil diperbarui langsung oleh admin.',
            'processed_at': FieldValue.serverTimestamp(),
            'processed_by': auth.currentUser?.uid,
          });
        }
      }

      transaction.update(userRef, {
        'name': cleanName,
        'name_key': newKey,
        'kelas': cleanClass,
        'profile_updated_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Run once after installing the update to reserve names of existing accounts.
  /// Inactive accounts are skipped so their names can be reused.
  Future<Map<String, dynamic>> rebuildNameRegistry() async {
    await _requireAdmin();
    final users = await db.collection('users').get();
    final registry = await db.collection('user_names').get();
    final groups =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final doc in users.docs) {
      final data = doc.data();
      if (data['active'] == false) continue;
      final name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final key = NameRegistry.documentId(name);
      groups.putIfAbsent(key, () => []).add(doc);
    }

    final operations = <void Function(WriteBatch)>[];
    final activeKeys = <String>{};
    final conflicts = <Map<String, dynamic>>[];
    var indexed = 0;

    for (final entry in groups.entries) {
      final key = entry.key;
      final members = entry.value;
      activeKeys.add(key);
      QueryDocumentSnapshot<Map<String, dynamic>>? existing;
      for (final doc in registry.docs) {
        if (doc.id == key) {
          existing = doc;
          break;
        }
      }
      final owner = members.firstWhere(
        (doc) => doc.id == existing?.data()['uid'],
        orElse: () => members.first,
      );
      final name = (owner.data()['name'] ?? '').toString();
      operations.add((batch) {
        batch.set(db.collection('user_names').doc(key), {
          'uid': owner.id,
          'display_name': name,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
      for (final member in members) {
        operations.add((batch) {
          batch.update(member.reference, {'name_key': key});
        });
        indexed++;
      }
      if (members.length > 1) {
        conflicts.add({
          'normalized_name': NameRegistry.normalize(name),
          'user_ids': members.map((e) => e.id).toList(),
        });
      }
    }

    for (final doc in registry.docs) {
      if (!activeKeys.contains(doc.id)) {
        operations.add((batch) {
          batch.delete(doc.reference);
        });
      }
    }

    // Firestore batches support up to 500 writes; keep a safety margin.
    for (var i = 0; i < operations.length; i += 400) {
      final batch = db.batch();
      for (final operation in operations.skip(i).take(400)) {
        operation(batch);
      }
      await batch.commit();
    }

    await db.collection('app_config').doc('username_registry').set({
      'ready': true,
      'indexed_count': indexed,
      'conflict_count': conflicts.length,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return {
      'indexed': indexed,
      'conflicts': conflicts,
      'conflict_count': conflicts.length,
    };
  }

  Future<void> _requireAdmin() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');
    final profile = await db.collection('users').doc(user.uid).get();
    if (profile.data()?['role'] != 'admin' ||
        profile.data()?['active'] == false) {
      throw Exception('Fitur ini hanya untuk admin aktif.');
    }
  }
}
