import 'dart:convert';

class NameRegistry {
  static String normalize(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String documentId(String name) =>
      base64Url.encode(utf8.encode(normalize(name))).replaceAll('=', '');
}
