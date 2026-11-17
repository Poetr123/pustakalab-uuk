import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  const ItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.code,
    required this.status,
    required this.image,
    required this.specification,
    this.borrowerName = '',
    this.borrowerUid = '',
    this.borrowerClass = '',
    this.dueAt,
    this.createdAt,
    this.activeBorrowingId = '',
  });

  final String id;
  final String name;
  final String category;
  final String code;
  final String status;
  final String image;
  final String specification;
  final String borrowerName;
  final String borrowerUid;
  final String borrowerClass;
  final DateTime? dueAt;
  final DateTime? createdAt;
  final String activeBorrowingId;

  bool get isAvailable => status == 'Available';
  bool get isBorrowed => status == 'Borrowed';

  factory ItemModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ItemModel(
      id: documentId,
      name: (data['item_name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      code: (data['code'] ?? '').toString(),
      status: (data['status'] ?? 'Available').toString(),
      image: (data['image'] ?? '').toString(),
      specification: (data['spesification'] ?? data['specification'] ?? '').toString(),
      borrowerName: (data['borrower_name'] ?? '').toString(),
      borrowerUid: (data['borrower_uid'] ?? '').toString(),
      borrowerClass: (data['borrower_class'] ?? '').toString(),
      dueAt: _readDate(data['borrow_due_at']),
      createdAt: _readDate(data['created_at']),
      activeBorrowingId: (data['active_borrowing_id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'item_id': id,
        'item_name': name,
        'category': category,
        'code': code,
        'status': status,
        'image': image,
        'spesification': specification,
      };

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
