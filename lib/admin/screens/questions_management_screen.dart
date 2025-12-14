import 'package:flutter/material.dart';
import '../../models/car_question.dart';
import '../../services/car_question_service.dart';
import 'package:intl/intl.dart';

class QuestionsManagementScreen extends StatefulWidget {
  const QuestionsManagementScreen({Key? key}) : super(key: key);

  @override
  State<QuestionsManagementScreen> createState() =>
      _QuestionsManagementScreenState();
}

class _QuestionsManagementScreenState extends State<QuestionsManagementScreen> {
  final _carQuestionService = CarQuestionService();
  final _answerController = TextEditingController();
  bool _showUnansweredOnly = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _showAnswerDialog(CarQuestion question) async {
    _answerController.text = question.answer ?? '';

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Answer Question'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question from ${question.userEmail}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(question.question),
                const SizedBox(height: 16),
                TextField(
                  controller: _answerController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your answer...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_answerController.text.trim().isNotEmpty) {
                    await _carQuestionService.answerQuestion(
                      question.id,
                      _answerController.text.trim(),
                    );
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Submit Answer'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questions Management'),
        actions: [
          Switch(
            value: _showUnansweredOnly,
            onChanged: (value) {
              setState(() => _showUnansweredOnly = value);
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text('Unanswered Only')),
          ),
        ],
      ),
      body: StreamBuilder<List<CarQuestion>>(
        stream:
            _showUnansweredOnly
                ? _carQuestionService.getUnansweredQuestions()
                : _carQuestionService.getAllQuestions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final questions = snapshot.data!;

          if (questions.isEmpty) {
            return Center(
              child: Text(
                _showUnansweredOnly
                    ? 'No unanswered questions'
                    : 'No questions yet',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  question.userEmail,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Car ID: ${question.carId}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, y').format(question.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(question.question),
                      if (question.isAnswered) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Admin Response:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat(
                                'MMM d, y',
                              ).format(question.answeredAt!),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(question.answer!),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!question.isAnswered)
                            ElevatedButton(
                              onPressed: () => _showAnswerDialog(question),
                              child: const Text('Answer'),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Delete Question'),
                                      content: const Text(
                                        'Are you sure you want to delete this question?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirm == true) {
                                await _carQuestionService.deleteQuestion(
                                  question.id,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
