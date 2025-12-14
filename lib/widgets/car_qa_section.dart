import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/car_question.dart';
import '../services/car_question_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CarQASection extends StatefulWidget {
  final String carId;

  const CarQASection({Key? key, required this.carId}) : super(key: key);

  @override
  State<CarQASection> createState() => _CarQASectionState();
}

class _CarQASectionState extends State<CarQASection> {
  final _questionController = TextEditingController();
  final _carQuestionService = CarQuestionService();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String _searchQuery = '';
  Set<String> _likedQuestions = {};
  Map<String, int> _likeCounts = {};

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<String> _getUserDisplayName(String userId, [String? userEmail]) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!['name'] != null &&
          (doc.data()!['name'] as String).trim().isNotEmpty) {
        return doc.data()!['name'];
      }
    } catch (_) {}
    if (userEmail != null && userEmail.contains('@')) {
      return userEmail.split('@')[0];
    }
    return 'User';
  }

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await _carQuestionService.askQuestion(
        widget.carId,
        _questionController.text.trim(),
      );
      if (!mounted) return;
      _questionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question submitted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting question: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _toggleLike(String questionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _carQuestionService.likeQuestion(questionId, user.uid);
    final hasLiked = await _carQuestionService.hasUserLiked(
      questionId,
      user.uid,
    );
    if (mounted) {
      setState(() {
        if (hasLiked) {
          _likedQuestions.add(questionId);
        } else {
          _likedQuestions.remove(questionId);
        }
      });
    }
  }

  Future<void> _loadLikes(List<CarQuestion> questions) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    for (final q in questions) {
      if (!mounted) return;
      final hasLiked = await _carQuestionService.hasUserLiked(q.id, user.uid);
      if (!mounted) return;
      setState(() {
        _likeCounts[q.id] = q.likes;
        if (hasLiked) {
          _likedQuestions.add(q.id);
        } else {
          _likedQuestions.remove(q.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Questions & Answers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            StreamBuilder<List<CarQuestion>>(
              stream: _carQuestionService.getCarQuestions(widget.carId),
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.length : 0;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    minimumSize: Size(0, 36),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (!mounted) return;
                    if (snapshot.data != null && snapshot.data!.isNotEmpty) {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) {
                          List<CarQuestion> allQuestions = snapshot.data!;
                          String modalSearch = '';
                          return StatefulBuilder(
                            builder: (context, setModalState) {
                              List<CarQuestion> filteredQuestions =
                                  allQuestions;
                              if (modalSearch.isNotEmpty) {
                                final q = modalSearch.toLowerCase();
                                filteredQuestions =
                                    allQuestions.where((cq) {
                                      final questionText =
                                          cq.question.toLowerCase();
                                      final answerText =
                                          (cq.answer ?? '').toLowerCase();
                                      return questionText.contains(q) ||
                                          answerText.contains(q);
                                    }).toList();
                              }
                              return DraggableScrollableSheet(
                                expand: false,
                                initialChildSize: 0.85,
                                minChildSize: 0.5,
                                maxChildSize: 0.95,
                                builder: (context, scrollController) {
                                  return Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            24,
                                            24,
                                            24,
                                            12,
                                          ),
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Search Q&A',
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                color: Colors.red,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 0,
                                                    horizontal: 12,
                                                  ),
                                            ),
                                            onChanged: (value) {
                                              setModalState(() {
                                                modalSearch = value;
                                              });
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            controller: scrollController,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            itemCount: filteredQuestions.length,
                                            itemBuilder: (context, index) {
                                              final question =
                                                  filteredQuestions[index];
                                              return Card(
                                                margin: const EdgeInsets.only(
                                                  bottom: 16,
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Question Section
                                                      Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const CircleAvatar(
                                                            radius: 20,
                                                            child: Icon(
                                                              Icons.person,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  question
                                                                      .userEmail,
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  question
                                                                      .question,
                                                                ),
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Text(
                                                                      DateFormat(
                                                                        'dd MMM yyyy | HH:mm',
                                                                      ).format(
                                                                        question
                                                                            .createdAt,
                                                                      ),
                                                                      style: TextStyle(
                                                                        color:
                                                                            Colors.grey[600],
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                    const Spacer(),
                                                                    InkWell(
                                                                      onTap:
                                                                          () => _toggleLike(
                                                                            question.id,
                                                                          ),
                                                                      child: Row(
                                                                        children: [
                                                                          Icon(
                                                                            _likedQuestions.contains(
                                                                                  question.id,
                                                                                )
                                                                                ? Icons.thumb_up
                                                                                : Icons.thumb_up_outlined,
                                                                            color:
                                                                                Colors.red,
                                                                            size:
                                                                                18,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                          Text(
                                                                            (_likeCounts[question.id] ??
                                                                                    question.likes)
                                                                                .toString(),
                                                                            style: const TextStyle(
                                                                              fontSize:
                                                                                  12,
                                                                              color:
                                                                                  Colors.red,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (question
                                                          .isAnswered) ...[
                                                        const Divider(
                                                          height: 32,
                                                        ),
                                                        // Answer Section
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Colors
                                                                    .grey[100],
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  const CircleAvatar(
                                                                    radius: 16,
                                                                    backgroundColor:
                                                                        Colors
                                                                            .red,
                                                                    child: Icon(
                                                                      Icons
                                                                          .verified,
                                                                      color:
                                                                          Colors
                                                                              .white,
                                                                      size: 16,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const Row(
                                                                        children: [
                                                                          Text(
                                                                            'RevX Support',
                                                                            style: TextStyle(
                                                                              fontWeight:
                                                                                  FontWeight.bold,
                                                                              color:
                                                                                  Colors.red,
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                          Icon(
                                                                            Icons.verified,
                                                                            color:
                                                                                Colors.red,
                                                                            size:
                                                                                16,
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      Text(
                                                                        question.answeredAt !=
                                                                                null
                                                                            ? DateFormat(
                                                                              'dd MMM yyyy | HH:mm',
                                                                            ).format(
                                                                              question.answeredAt!,
                                                                            )
                                                                            : '',
                                                                        style: TextStyle(
                                                                          color:
                                                                              Colors.grey[600],
                                                                          fontSize:
                                                                              12,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              Text(
                                                                question.answer ??
                                                                    '',
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    }
                  },
                  child: Text('All ($count)'),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (user != null) ...[
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    hintText: 'Ask a question about this car...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your question';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSubmitting ? null : _submitQuestion,
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Ask Us'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        StreamBuilder<List<CarQuestion>>(
          stream: _carQuestionService.getCarQuestions(widget.carId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            List<CarQuestion> questions = snapshot.data!;
            if (mounted) {
              _loadLikes(questions);
            }
            if (questions.isEmpty) {
              return const Center(
                child: Text('No questions yet. Be the first to ask!'),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                return FutureBuilder<String>(
                  future: _getUserDisplayName(
                    question.userId,
                    question.userEmail,
                  ),
                  builder: (context, nameSnapshot) {
                    final askerName = nameSnapshot.data ?? 'User';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                askerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat(
                                  'dd MMMM yyyy | HH:mm',
                                  'en_US',
                                ).format(question.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            question.question,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (question.isAnswered && question.answer != null)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.verified,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'RevX',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          question.answer!,
                                          style: const TextStyle(fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          question.answeredAt != null
                                              ? _getAnswerTimeDiff(
                                                question.createdAt,
                                                question.answeredAt!,
                                              )
                                              : '',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _getAnswerTimeDiff(DateTime questionTime, DateTime answerTime) {
    final diff = answerTime.difference(questionTime);
    if (diff.inMinutes < 60) {
      return 'Answered in ${diff.inMinutes} minutes';
    } else if (diff.inHours < 24) {
      return 'Answered in ${diff.inHours} hours';
    } else {
      return 'Answered in ${diff.inDays} days';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else {
      return '${(diff.inDays / 365).floor()} years ago';
    }
  }
}
