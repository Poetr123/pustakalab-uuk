import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'name_registry.dart';

class BorrowingService {
  BorrowingService({FirebaseFirestore? db, FirebaseAuth? auth})
      : db = db ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore db;
  final FirebaseAuth auth;

  static const int maxDurationDays = 14;
  CollectionReference<Map<String, dynamic>> get _borrowings => db.collection('borrowings');
  CollectionReference<Map<String, dynamic>> get _requests => db.collection('requests');

  Stream<List<Map<String, dynamic>>> streamAllBorrowings() =>
      _borrowings.snapshots().map(_sortedRecords);

  Stream<List<Map<String, dynamic>>> streamMyBorrowings() {
    final user = auth.currentUser;
    if (user == null) return const Stream.empty();
    return db.collection('users').doc(user.uid).collection('borrowings')
        .snapshots().map(_sortedRecords);
  }

  Stream<List<Map<String, dynamic>>> streamPendingRequests() =>
      _requests.where('status', isEqualTo: 'pending').snapshots().map((snapshot) {
        final records = snapshot.docs
            .map((doc) => {...doc.data(), 'document_id': doc.id})
            .toList();
        records.sort((a, b) =>
            (_asDate(b['created_at']) ?? DateTime(2000))
                .compareTo(_asDate(a['created_at']) ?? DateTime(2000)));
        return records;
      });

  Stream<List<Map<String, dynamic>>> streamPendingBorrowRequests() =>
      streamPendingRequests().map((rows) => rows
          .where((row) => row['request_type'] == 'borrow')
          .toList());

  Stream<List<Map<String, dynamic>>> streamPendingProfileRequests() =>
      streamPendingRequests().map((rows) => rows
          .where((row) => row['request_type'] == 'profile_update')
          .toList());

  Future<void> submitBorrowRequest(
    String itemId, {
    required int durationDays,
  }) async {
    if (durationDays < 1 || durationDays > maxDurationDays) {
      throw Exception('Durasi peminjaman maksimal $maxDurationDays hari.');
    }
    final user = auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');

    final userRef = db.collection('users').doc(user.uid);
    final itemRef = db.collection('items').doc(itemId);
    final requestRef = _requests.doc();
    final personalBorrowRef =
        userRef.collection('borrowings').doc(requestRef.id);
    final createdAt = FieldValue.serverTimestamp();

    // Penguncian berlaku per alat, bukan per pengguna.
    // Pengguna boleh mengajukan alat lain selama alat tersebut tersedia.
    await db.runTransaction((transaction) async {
      final profileSnapshot = await transaction.get(userRef);
      final itemSnapshot = await transaction.get(itemRef);
      if (!profileSnapshot.exists) throw Exception('Profil pengguna tidak ditemukan.');
      if (!itemSnapshot.exists) throw Exception('Alat tidak ditemukan.');

      final profile = profileSnapshot.data() ?? {};
      final item = itemSnapshot.data() ?? {};
      final pendingRequestId =
          (item['pending_borrow_request_id'] ?? '').toString();
      if (item['status'] != 'Available') {
        throw Exception('Alat sedang dipinjam dan tidak tersedia.');
      }
      if (pendingRequestId.isNotEmpty) {
        throw Exception(
          'Alat ini sudah memiliki pengajuan peminjaman yang menunggu keputusan admin.',
        );
      }
      final borrowerName = (profile['name'] ?? user.displayName ?? '').toString().trim();
      if (borrowerName.isEmpty) throw Exception('Nama peminjam belum tersedia di profil.');

      final payload = <String, dynamic>{
        'borrow_id': requestRef.id,
        'owner_uid': user.uid,
        'borrower_uid': user.uid,
        'borrower_name': borrowerName,
        'borrower_class': (profile['kelas'] ?? '').toString(),
        'item_id': itemId,
        'item_name': (item['item_name'] ?? '').toString(),
        'item_code': (item['code'] ?? '').toString(),
        'item_image': (item['image'] ?? '').toString(),
        'duration_days': durationDays,
        'status': 'pending',
        'request_date': createdAt,
        'created_at': createdAt,
      };

      transaction.set(personalBorrowRef, payload);
      transaction.update(itemRef, {
        'pending_borrow_request_id': requestRef.id,
      });
      transaction.set(requestRef, {
        ...payload,
        'request_type': 'borrow',
        'requester_uid': user.uid,
        'status': 'pending',
      });
    });
  }

  Future<void> submitProfileChangeRequest({
    required String requestedName,
    required String requestedClass,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');
    final userRef = db.collection('users').doc(user.uid);
    final requestRef = _requests.doc();
    final profile = await userRef.get();
    final oldData = profile.data() ?? {};
    if (!profile.exists) throw Exception('Profil pengguna tidak ditemukan.');

    final name = requestedName.trim();
    final kelas = requestedClass.trim();
    if (name.isEmpty || kelas.isEmpty) throw Exception('Nama dan kelas wajib diisi.');
    if (name.toLowerCase() == (oldData['name'] ?? '').toString().trim().toLowerCase() &&
        kelas.toLowerCase() == (oldData['kelas'] ?? '').toString().trim().toLowerCase()) {
      throw Exception('Tidak ada perubahan profil.');
    }

    await requestRef.set({
      'request_type': 'profile_update',
      'owner_uid': user.uid,
      'requester_uid': user.uid,
      'current_name': (oldData['name'] ?? '').toString(),
      'current_class': (oldData['kelas'] ?? '').toString(),
      'requested_name': name,
      'requested_class': kelas,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveBorrowRequest(String requestId) async {
    await _requireAdmin();
    final requestRef = _requests.doc(requestId);
    await db.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) throw Exception('Permintaan tidak ditemukan.');
      final request = requestSnapshot.data()!;
      if (request['request_type'] != 'borrow' || request['status'] != 'pending') {
        throw Exception('Permintaan ini sudah diproses.');
      }

      final uid = (request['owner_uid'] ?? request['borrower_uid'] ?? '').toString();
      final itemId = (request['item_id'] ?? '').toString();
      if (uid.isEmpty || itemId.isEmpty) throw Exception('Data permintaan tidak lengkap.');
      final itemRef = db.collection('items').doc(itemId);
      final personalRef = db.collection('users').doc(uid).collection('borrowings').doc(requestId);
      final globalRef = _borrowings.doc(requestId);
      final itemSnapshot = await transaction.get(itemRef);
      final personalSnapshot = await transaction.get(personalRef);
      if (!itemSnapshot.exists || !personalSnapshot.exists) {
        throw Exception('Data alat atau riwayat peminjam tidak ditemukan.');
      }
      final item = itemSnapshot.data()!;
      if (item['status'] != 'Available') {
        throw Exception('Alat sudah dipinjam atau tidak tersedia. Tolak permintaan ini.');
      }
      if (item['pending_borrow_request_id'] != requestId) {
        throw Exception('Penanda pengajuan alat tidak cocok. Muat ulang permintaan.');
      }

      final days = (request['duration_days'] as num?)?.toInt() ?? 7;
      final dueAt = DateTime.now().add(Duration(days: days));
      final activePayload = <String, dynamic>{
        ...request,
        'borrow_id': requestId,
        'owner_uid': uid,
        'borrower_uid': uid,
        'borrow_date': FieldValue.serverTimestamp(),
        'approved_at': FieldValue.serverTimestamp(),
        'due_at': Timestamp.fromDate(dueAt),
        'status': 'active',
        'approved_by': auth.currentUser?.uid,
      };

      transaction.update(itemRef, {
        'status': 'Borrowed',
        'pending_borrow_request_id': FieldValue.delete(),
        'active_borrowing_id': requestId,
        'borrower_uid': uid,
        'borrower_name': (request['borrower_name'] ?? '').toString(),
        'borrower_class': (request['borrower_class'] ?? '').toString(),
        'borrow_due_at': Timestamp.fromDate(dueAt),
      });
      transaction.update(personalRef, activePayload);
      transaction.set(globalRef, activePayload);
      transaction.update(requestRef, {
        'status': 'approved',
        'processed_at': FieldValue.serverTimestamp(),
        'processed_by': auth.currentUser?.uid,
      });
    });
  }

  Future<void> rejectRequest(String requestId, {String note = ''}) async {
    await _requireAdmin();
    final requestRef = _requests.doc(requestId);
    await db.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) throw Exception('Permintaan tidak ditemukan.');
      final request = requestSnapshot.data()!;
      if (request['status'] != 'pending') throw Exception('Permintaan sudah diproses.');
      final uid = (request['owner_uid'] ?? '').toString();
      final userRef = db.collection('users').doc(uid);
      final personalRef = userRef.collection('borrowings').doc(requestId);
      final itemId = (request['item_id'] ?? '').toString();
      final itemRef = itemId.isEmpty
          ? null
          : db.collection('items').doc(itemId);
      DocumentSnapshot<Map<String, dynamic>>? personalSnapshot;
      DocumentSnapshot<Map<String, dynamic>>? itemSnapshot;
      if (request['request_type'] == 'borrow') {
        personalSnapshot = await transaction.get(personalRef);
        if (itemRef != null) {
          itemSnapshot = await transaction.get(itemRef);
        }
      }
      transaction.update(requestRef, {
        'status': 'rejected',
        'review_note': note,
        'processed_at': FieldValue.serverTimestamp(),
        'processed_by': auth.currentUser?.uid,
      });
      if (personalSnapshot?.exists == true) {
        transaction.update(personalRef, {
          'status': 'rejected',
          'review_note': note,
          'processed_at': FieldValue.serverTimestamp(),
        });
      }
      if (itemRef != null &&
          itemSnapshot?.exists == true &&
          itemSnapshot?.data()?['pending_borrow_request_id'] == requestId) {
        transaction.update(itemRef, {
          'pending_borrow_request_id': FieldValue.delete(),
        });
      }
    });
  }

  Future<void> approveProfileUpdateRequest(String requestId) async {
    await _requireAdmin();
    final requestRef = _requests.doc(requestId);

    // Read the legacy name group outside the transaction because the Flutter
    // Transaction API reads document references, not query objects. The
    // documents are re-read inside the transaction before they can be used.
    final initialRequest = await requestRef.get();
    if (!initialRequest.exists) throw Exception('Permintaan tidak ditemukan.');
    final initialUid = (initialRequest.data()?['owner_uid'] ?? '').toString();
    final initialUser = await db.collection('users').doc(initialUid).get();
    final initialOldKey = (initialUser.data()?['name_key'] ?? '').toString();
    final requestedName = (initialRequest.data()?['requested_name'] ?? '').toString().trim();
    final requestedKey = NameRegistry.documentId(requestedName);
    QuerySnapshot<Map<String, dynamic>>? legacyNameGroup;
    if (initialOldKey.isNotEmpty && initialOldKey != requestedKey) {
      legacyNameGroup = await db.collection('users')
          .where('name_key', isEqualTo: initialOldKey)
          .limit(10)
          .get();
    }

    await db.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) throw Exception('Permintaan tidak ditemukan.');
      final request = requestSnapshot.data()!;
      if (request['request_type'] != 'profile_update' || request['status'] != 'pending') {
        throw Exception('Permintaan profil sudah diproses.');
      }
      final uid = (request['owner_uid'] ?? '').toString();
      final userRef = db.collection('users').doc(uid);
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw Exception('Pengguna tidak ditemukan.');

      final oldData = userSnapshot.data()!;
      final oldKey = (oldData['name_key'] ?? '').toString();
      if (oldKey != initialOldKey) {
        throw Exception('Profil pengguna berubah saat permintaan diproses. Muat ulang lalu coba lagi.');
      }
      final newName = (request['requested_name'] ?? '').toString().trim();
      final newClass = (request['requested_class'] ?? '').toString().trim();
      if (newName.isEmpty || newClass.isEmpty) throw Exception('Nama dan kelas baru tidak valid.');

      final newKey = NameRegistry.documentId(newName);
      final newNameRef = db.collection('user_names').doc(newKey);
      final oldNameRef = oldKey.isEmpty ? null : db.collection('user_names').doc(oldKey);
      final newNameSnapshot = newKey == oldKey ? null : await transaction.get(newNameRef);
      final oldNameSnapshot = oldKey.isEmpty || newKey == oldKey
          ? null
          : await transaction.get(oldNameRef!);
      if (newNameSnapshot?.exists == true && newNameSnapshot?.data()?['uid'] != uid) {
        throw Exception('Nama tersebut sudah digunakan oleh pengguna lain.');
      }

      final remainingLegacyUsers = <DocumentSnapshot<Map<String, dynamic>>>[];
      if (oldKey.isNotEmpty && newKey != oldKey && legacyNameGroup != null) {
        for (final candidate in legacyNameGroup.docs) {
          if (candidate.id == uid) continue;
          final currentCandidate = await transaction.get(candidate.reference);
          if (currentCandidate.exists && currentCandidate.data()?['name_key'] == oldKey) {
            remainingLegacyUsers.add(currentCandidate);
          }
        }
      }

      if (newKey != oldKey) {
        transaction.set(newNameRef, {
          'uid': uid,
          'display_name': newName,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Only move a registry entry if this account currently owns it. If
        // legacy duplicates remain, reserve the old key for one of them.
        if (oldNameRef != null && oldNameSnapshot?.data()?['uid'] == uid) {
          if (remainingLegacyUsers.isEmpty) {
            transaction.delete(oldNameRef);
          } else {
            final nextOwner = remainingLegacyUsers.first;
            transaction.set(oldNameRef, {
              'uid': nextOwner.id,
              'display_name': (nextOwner.data()?['name'] ?? '').toString(),
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      transaction.update(userRef, {
        'name': newName,
        'name_key': newKey,
        'kelas': newClass,
        'profile_updated_at': FieldValue.serverTimestamp(),
      });
      transaction.update(requestRef, {
        'status': 'approved',
        'processed_at': FieldValue.serverTimestamp(),
        'processed_by': auth.currentUser?.uid,
      });
    });
  }

  Future<void> returnItem({required String itemId, required String borrowingId}) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');
    await _closeBorrowing(itemId: itemId, borrowingId: borrowingId, expectedUid: user.uid);
  }

  Future<void> adminReturnItem({required String itemId, required String borrowingId}) async {
    await _requireAdmin();
    await _closeBorrowing(itemId: itemId, borrowingId: borrowingId, admin: true);
  }

  Future<void> _closeBorrowing({
    required String itemId,
    required String borrowingId,
    String? expectedUid,
    bool admin = false,
  }) async {
    final globalRef = _borrowings.doc(borrowingId);
    final globalSnapshot = await globalRef.get();
    if (!globalSnapshot.exists) throw Exception('Riwayat peminjaman tidak ditemukan.');
    final globalData = globalSnapshot.data()!;
    final uid = (globalData['owner_uid'] ?? globalData['borrower_uid'] ?? '').toString();
    if (!admin && uid != expectedUid) throw Exception('Hanya peminjam yang dapat mengembalikan alat.');

    final itemRef = db.collection('items').doc(itemId);
    final personalRef = db.collection('users').doc(uid)
        .collection('borrowings').doc(borrowingId);

    await db.runTransaction((transaction) async {
      final itemSnapshot = await transaction.get(itemRef);
      final globalBorrowSnapshot = await transaction.get(globalRef);
      final personalSnapshot = await transaction.get(personalRef);
      if (!itemSnapshot.exists || !globalBorrowSnapshot.exists) {
        throw Exception('Data alat atau riwayat tidak ditemukan.');
      }
      final item = itemSnapshot.data()!;
      final borrow = globalBorrowSnapshot.data()!;
      if (borrow['status'] != 'active') throw Exception('Peminjaman ini sudah ditutup.');
      if (item['status'] != 'Borrowed' ||
          (item['active_borrowing_id'] != null && item['active_borrowing_id'] != borrowingId)) {
        throw Exception('Status inventaris tidak cocok dengan riwayat peminjaman.');
      }
      final returnData = {
        'status': 'returned',
        'return_date': FieldValue.serverTimestamp(),
        'returned_by': auth.currentUser?.uid,
      };
      transaction.update(itemRef, {
        'status': 'Available',
        'active_borrowing_id': FieldValue.delete(),
        'borrower_uid': FieldValue.delete(),
        'borrower_name': FieldValue.delete(),
        'borrower_email': FieldValue.delete(),
        'borrower_class': FieldValue.delete(),
        'borrow_due_at': FieldValue.delete(),
      });
      transaction.update(globalRef, returnData);
      if (personalSnapshot.exists) transaction.update(personalRef, returnData);
    });
  }

  /// One-time bridge for legacy personal histories into the shared history.
  /// It preserves the personal subcollection and creates/refreshes the root
  /// document used by the global history screen. It never uses collectionGroup.
  Future<int> migrateLegacyBorrowingsToRootIfAdmin() async {
    await _requireAdmin();
    final admin = auth.currentUser!;
    const migrationId = 'legacy_borrowings_to_root_v4';
    final markerRef = db.collection('_system_migrations').doc(migrationId);
    final marker = await markerRef.get();
    if (marker.data()?['completed'] == true) return 0;

    final users = await db.collection('users').get();
    final legacyRecords = <Map<String, dynamic>>[];
    final itemIds = <String>{};

    // Collect personal records first so legacy records without borrower_uid or
    // active_borrowing_id can be resolved to the latest loan for each item.
    for (final userDoc in users.docs) {
      final oldRecords = await userDoc.reference.collection('borrowings').get();
      for (final oldDoc in oldRecords.docs) {
        final data = oldDoc.data();
        final sourceStatus = (data['status'] ?? '').toString().toLowerCase();
        if (sourceStatus == 'pending' || sourceStatus == 'rejected') continue;
        final itemId = (data['item_id'] ?? '').toString();
        if (itemId.isNotEmpty) itemIds.add(itemId);
        legacyRecords.add({
          'uid': userDoc.id,
          'id': oldDoc.id,
          'ref': oldDoc.reference,
          'data': data,
          'profile': userDoc.data(),
          'source_status': sourceStatus,
          'item_id': itemId,
        });
      }
    }

    final latestByItem = <String, Map<String, dynamic>>{};
    for (final record in legacyRecords) {
      final itemId = record['item_id'] as String;
      if (itemId.isEmpty) continue;
      final previous = latestByItem[itemId];
      final date = _asDate(
        (record['data'] as Map<String, dynamic>)['borrow_date'] ??
        (record['data'] as Map<String, dynamic>)['created_at'] ??
        (record['data'] as Map<String, dynamic>)['request_date'],
      );
      final previousData = previous?['data'] as Map<String, dynamic>?;
      final previousDate = previous == null
          ? null
          : _asDate(previousData?['borrow_date'] ?? previousData?['created_at'] ?? previousData?['request_date']);
      if (previous == null || (date != null && (previousDate == null || date.isAfter(previousDate)))) {
        latestByItem[itemId] = record;
      }
    }

    final itemDataById = <String, Map<String, dynamic>>{};
    for (final itemId in itemIds) {
      final itemSnapshot = await db.collection('items').doc(itemId).get();
      itemDataById[itemId] = itemSnapshot.data() ?? <String, dynamic>{};
    }

    var migrated = 0;
    var writes = 0;
    WriteBatch batch = db.batch();

    for (final record in legacyRecords) {
      final uid = record['uid'] as String;
      final borrowId = record['id'] as String;
      final personalRef = record['ref'] as DocumentReference<Map<String, dynamic>>;
      final data = record['data'] as Map<String, dynamic>;
      final profile = record['profile'] as Map<String, dynamic>;
      final itemId = record['item_id'] as String;
      final sourceStatus = record['source_status'] as String;
      final item = itemDataById[itemId] ?? const <String, dynamic>{};
      final itemBorrowed = item['status'] == 'Borrowed';
      final pointer = (item['active_borrowing_id'] ?? '').toString();
      final itemBorrower = (item['borrower_uid'] ?? '').toString();
      final pointerMatches = pointer.isNotEmpty && pointer == borrowId &&
          (itemBorrower.isEmpty || itemBorrower == uid);
      final borrowerMatches = itemBorrower.isNotEmpty && itemBorrower == uid &&
          (pointer.isEmpty || pointer == borrowId);
      final legacyLatestMatches = pointer.isEmpty && itemBorrower.isEmpty &&
          latestByItem[itemId]?['id'] == borrowId;
      final isCurrentBorrower = itemBorrowed &&
          (pointerMatches || borrowerMatches || legacyLatestMatches);

      String migratedStatus;
      if (sourceStatus == 'available' || sourceStatus == 'returned') {
        migratedStatus = 'returned';
      } else {
        // A stale legacy 'active' flag is corrected if the inventory no longer
        // points to this loan. Old schema records with no status are inferred
        // from the current item and latest borrow date.
        migratedStatus = isCurrentBorrower ? 'active' : 'returned';
      }

      final personalData = <String, dynamic>{
        ...data,
        'borrow_id': borrowId,
        'owner_uid': uid,
        'borrower_uid': (data['borrower_uid'] ?? uid).toString(),
        'borrower_name': (data['borrower_name'] ?? profile['name'] ?? '').toString(),
        'borrower_class': (data['borrower_class'] ?? profile['kelas'] ?? '').toString(),
        'item_name': (data['item_name'] ?? item['item_name'] ?? 'Alat').toString(),
        'item_code': (data['item_code'] ?? item['code'] ?? '').toString(),
        'item_image': (data['item_image'] ?? item['image'] ?? '').toString(),
        'status': migratedStatus,
        'migrated_from_legacy': true,
        'migrated_at': FieldValue.serverTimestamp(),
      };
      final rootData = Map<String, dynamic>.from(personalData)
        ..remove('borrower_email');
      final rootRef = _borrowings.doc(borrowId);
      final existingRoot = await rootRef.get();
      final existingOwner = (existingRoot.data()?['owner_uid'] ??
          existingRoot.data()?['borrower_uid'] ?? '').toString();

      // Keep the original ID so an item's active_borrowing_id remains valid.
      // In the extremely unlikely event of an ID collision across user
      // subcollections, preserve the existing root document and leave this
      // personal history intact rather than overwriting another borrower.
      if (!existingRoot.exists || existingOwner.isEmpty || existingOwner == uid) {
        if (existingRoot.exists) {
          final rootPatch = Map<String, dynamic>.from(rootData);
          if (existingRoot.data()?.containsKey('borrower_email') == true) {
            rootPatch['borrower_email'] = FieldValue.delete();
          }
          batch.set(rootRef, rootPatch, SetOptions(merge: true));
        } else {
          batch.set(rootRef, rootData);
        }
        migrated++;
        writes++;
      }
      batch.set(personalRef, personalData, SetOptions(merge: true));
      writes++;

      if (writes >= 400) {
        await batch.commit();
        batch = db.batch();
        writes = 0;
      }
    }

    if (writes > 0) await batch.commit();
    await markerRef.set({
      'completed': true,
      'completed_at': FieldValue.serverTimestamp(),
      'completed_by': admin.uid,
      'migrated_count': migrated,
      'version': 4,
    });
    return migrated;
  }

  Future<void> _requireAdmin() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');
    final profile = await db.collection('users').doc(user.uid).get();
    if (profile.data()?['role'] != 'admin' || profile.data()?['active'] == false) {
      throw Exception('Fitur ini hanya untuk admin aktif.');
    }
  }

  static List<Map<String, dynamic>> _sortedRecords(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final records = snapshot.docs
        .map((doc) => {...doc.data(), 'document_id': doc.id})
        .toList();
    records.sort((a, b) =>
        (_asDate(b['borrow_date'] ?? b['request_date'] ?? b['created_at']) ?? DateTime(2000))
            .compareTo(_asDate(a['borrow_date'] ?? a['request_date'] ?? a['created_at']) ?? DateTime(2000)));
    return records;
  }

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
