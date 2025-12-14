import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String role;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    return AppUser(
      uid: documentId,
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'role': role, 'createdAt': createdAt};
  }
}
