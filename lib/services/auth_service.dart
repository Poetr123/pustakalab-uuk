import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'name_registry.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserData() {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user.uid).snapshots();
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    final profile = await _db.collection('users').doc(user.uid).get();
    return profile.data()?['role'] == 'admin' && profile.data()?['active'] != false;
  }

  Future<String?> register({
    required String name,
    required String kelas,
    required String email,
    required String password,
  }) async {
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'Akun berhasil dibuat, tetapi UID tidak ditemukan.';

      final registryState = await _db.collection('app_config').doc('username_registry').get();
      if (registryState.data()?['ready'] != true) {
        await _deleteNewAuthUser(user);
        return 'Pendaftaran sementara belum dibuka. Admin harus menyinkronkan daftar nama pengguna terlebih dahulu.';
      }

      final nameKey = NameRegistry.documentId(name);
      final nameRef = _db.collection('user_names').doc(nameKey);
      final userRef = _db.collection('users').doc(user.uid);

      await _db.runTransaction((transaction) async {
        final existingName = await transaction.get(nameRef);
        if (existingName.exists) {
          throw const _DuplicateNameException();
        }
        transaction.set(nameRef, {
          'uid': user.uid,
          'display_name': name.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });
        transaction.set(userRef, {
          'user_id': user.uid,
          'name': name.trim(),
          'name_key': nameKey,
          'email': email.trim(),
          'kelas': kelas.trim(),
          'created_at': FieldValue.serverTimestamp(),
          'foto': '',
          'role': 'user',
          'active': true,
        });
      });

      await _auth.signOut();
      return null;
    } on _DuplicateNameException {
      await _deleteNewAuthUser(credential?.user);
      return 'Nama tersebut sudah digunakan. Gunakan nama lain.';
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } on FirebaseException catch (e) {
      await _deleteNewAuthUser(credential?.user);
      return e.message ?? 'Gagal menyimpan profil pengguna.';
    } catch (e) {
      await _deleteNewAuthUser(credential?.user);
      return 'Terjadi kesalahan saat mendaftar: $e';
    }
  }

  Future<void> _deleteNewAuthUser(User? user) async {
    try {
      await user?.delete();
    } catch (_) {
      // The Firestore transaction failed just after account creation. The
      // account is signed out below; an admin can clean up an orphan if needed.
    }
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<String?> login({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'Akun tidak ditemukan.';

      final profile = await _db.collection('users').doc(user.uid).get();
      if (!profile.exists) {
        await _auth.signOut();
        return 'Profil akun tidak ditemukan atau sudah dihapus. Hubungi admin.';
      }
      if (profile.data()?['active'] == false) {
        await _auth.signOut();
        return 'Akun sedang dinonaktifkan. Hubungi admin.';
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Gagal login: $e';
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return 'Sesi login tidak ditemukan. Silakan login kembali.';
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Password saat ini tidak sesuai.';
        case 'weak-password':
          return 'Password baru terlalu lemah. Gunakan minimal 6 karakter.';
        case 'requires-recent-login':
          return 'Sesi perlu diperbarui. Silakan logout lalu login kembali.';
        case 'network-request-failed':
          return 'Koneksi internet bermasalah.';
        default:
          return e.message ?? 'Gagal mengganti password.';
      }
    } catch (e) {
      return 'Gagal mengganti password: $e';
    }
  }

  Future<void> logout() => _auth.signOut();

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah.';
      default:
        return e.message ?? 'Autentikasi gagal.';
    }
  }
}

class _DuplicateNameException implements Exception {
  const _DuplicateNameException();
}
