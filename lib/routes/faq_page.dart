import 'package:flutter/material.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  _FaqPageState createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  // List of questions and their answers
  final List<Map<String, String>> _faqData = [
    {
      "question": "How do I rent a car?",
      "answer":
          "To rent a car, simply choose the car you want, provide your personal and payment details, and complete the booking. You will receive a confirmation and pick-up details.",
    },
    {
      "question": "What are the requirements to rent a car?",
      "answer":
          "Renters must be at least 21 years old, with a valid driver's license for a minimum of one year. Additional requirements may apply depending on the vehicle.",
    },
    {
      "question": "Can I cancel my booking?",
      "answer":
          "Yes, you can cancel your booking up to 24 hours before the scheduled pick-up time. Cancellation fees may apply.",
    },
    {
      "question": "Is insurance included in the rental price?",
      "answer":
          "Basic insurance is included in the rental price, but additional coverage options are available for purchase.",
    },
    {
      "question": "What happens if I return the car late?",
      "answer":
          "Late returns may incur additional charges. You will be charged an hourly or daily fee depending on the length of the delay.",
    },
    {
      "question": "Can I extend my rental period?",
      "answer":
          "Yes, you can extend your rental period by contacting our customer support team. Extensions are subject to availability.",
    },
    {
      "question": "Do you offer airport delivery and pick-up?",
      "answer":
          "Yes, we offer delivery and pick-up services at selected airports. Additional fees may apply.",
    },
  ];

  // List to keep track of which questions are expanded
  List<bool> _expanded = List.generate(7, (_) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Frequently Asked Questions")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView.builder(
          itemCount: _faqData.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ExpansionTile(
                title: Text(
                  _faqData[index]['question']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      _faqData[index]['answer']!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
                initiallyExpanded: _expanded[index],
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expanded[index] = expanded;
                  });
                },
                trailing: Icon(
                  _expanded[index] ? Icons.remove : Icons.add,
                  size: 30,
                  color: Colors.red,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
