import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/car_question.dart';

class CarQuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Ask a question about a car
  Future<void> askQuestion(String carId, String question) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception('User must be logged in to ask questions');

    final questionData = CarQuestion(
      id: '', // Will be set by Firestore
      carId: carId,
      userId: user.uid,
      userEmail: user.email ?? '',
      question: question,
      createdAt: DateTime.now(),
      isAnswered: false,
      likes: 0,
    );

    await _firestore.collection('carQuestions').add(questionData.toMap());
  }

  // Get all questions for a specific car
  Stream<List<CarQuestion>> getCarQuestions(String carId) {
    return _firestore
        .collection('carQuestions')
        .where('carId', isEqualTo: carId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CarQuestion.fromFirestore(doc))
                  .toList()
                ..sort(
                  (a, b) => b.createdAt.compareTo(a.createdAt),
                ), // Sort in memory
        );
  }

  // Get all unanswered questions (for admin)
  Stream<List<CarQuestion>> getUnansweredQuestions() {
    return _firestore
        .collection('carQuestions')
        .where('isAnswered', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CarQuestion.fromFirestore(doc))
                  .toList()
                ..sort(
                  (a, b) => b.createdAt.compareTo(a.createdAt),
                ), // Sort in memory
        );
  }

  // Get all questions (for admin)
  Stream<List<CarQuestion>> getAllQuestions() {
    return _firestore
        .collection('carQuestions')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CarQuestion.fromFirestore(doc))
                  .toList()
                ..sort(
                  (a, b) => b.createdAt.compareTo(a.createdAt),
                ), // Sort in memory
        );
  }

  // Answer a question (admin only)
  Future<void> answerQuestion(String questionId, String answer) async {
    await _firestore.collection('carQuestions').doc(questionId).update({
      'answer': answer,
      'isAnswered': true,
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a question (admin only)
  Future<void> deleteQuestion(String questionId) async {
    await _firestore.collection('carQuestions').doc(questionId).delete();
  }

  Future<void> likeQuestion(String questionId, String userId) async {
    final docRef = _firestore.collection('carQuestions').doc(questionId);
    final likeDoc = docRef.collection('likes').doc(userId);
    final likeSnapshot = await likeDoc.get();
    if (likeSnapshot.exists) {
      // Unlike
      await likeDoc.delete();
      await docRef.update({'likes': FieldValue.increment(-1)});
    } else {
      // Like
      await likeDoc.set({'likedAt': FieldValue.serverTimestamp()});
      await docRef.update({'likes': FieldValue.increment(1)});
    }
  }

  Future<bool> hasUserLiked(String questionId, String userId) async {
    final likeDoc =
        await _firestore
            .collection('carQuestions')
            .doc(questionId)
            .collection('likes')
            .doc(userId)
            .get();
    return likeDoc.exists;
  }
}
