import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class MediaService {
  MediaService({FirebaseStorage? storage, FirebaseAuth? auth})
    : storage = storage ?? FirebaseStorage.instance,
      auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage storage;
  final FirebaseAuth auth;

  static const int maxBytes = 5 * 1024 * 1024;

  static const List<String> allowedExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'svg',
  ];

  Future<String?> pickAndUpload({required String folder}) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Silakan login terlebih dahulu.');
    }

    // API file_picker versi baru
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (file == null) return null;

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('File gambar tidak dapat dibaca.');
    }

    if (bytes.length > maxBytes) {
      throw Exception('Ukuran gambar maksimal 5 MB.');
    }

    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';

    final contentType = _contentType(extension);
    if (contentType == null) {
      throw Exception('Format gambar tidak didukung.');
    }

    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final ref = storage.ref().child(
      '$folder/${user.uid}/${timestamp}_$safeName',
    );

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'ownerUid': user.uid},
      ),
    );

    return ref.getDownloadURL();
  }

  Future<void> deleteByUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;

    try {
      await storage.refFromURL(url).delete();
    } catch (_) {
      // URL eksternal atau file yang sudah dihapus.
    }
  }

  String? _contentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      default:
        return null;
    }
  }
}
