import 'package:cloud_firestore/cloud_firestore.dart';

class CarQuestion {
  final String id;
  final String carId;
  final String userId;
  final String userEmail;
  final String question;
  final String? answer;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final bool isAnswered;
  final int likes;

  CarQuestion({
    required this.id,
    required this.carId,
    required this.userId,
    required this.userEmail,
    required this.question,
    this.answer,
    required this.createdAt,
    this.answeredAt,
    required this.isAnswered,
    required this.likes,
  });

  factory CarQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CarQuestion(
      id: doc.id,
      carId: data['carId'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      question: data['question'] ?? '',
      answer: data['answer'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      answeredAt:
          data['answeredAt'] != null
              ? (data['answeredAt'] as Timestamp).toDate()
              : null,
      isAnswered: data['isAnswered'] ?? false,
      likes: data['likes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'carId': carId,
      'userId': userId,
      'userEmail': userEmail,
      'question': question,
      'answer': answer,
      'createdAt': Timestamp.fromDate(createdAt),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'isAnswered': isAnswered,
      'likes': likes,
    };
  }

  CarQuestion copyWith({
    String? id,
    String? carId,
    String? userId,
    String? userEmail,
    String? question,
    String? answer,
    DateTime? createdAt,
    DateTime? answeredAt,
    bool? isAnswered,
    int? likes,
  }) {
    return CarQuestion(
      id: id ?? this.id,
      carId: carId ?? this.carId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      createdAt: createdAt ?? this.createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      isAnswered: isAnswered ?? this.isAnswered,
      likes: likes ?? this.likes,
    );
  }
}
