import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Comment {
  final String text;
  final double rating;
  final DateTime timestamp;

  Comment({required this.text, required this.rating, required this.timestamp});

  Map<String, dynamic> toMap() {
    return {'text': text, 'rating': rating, 'timestamp': timestamp};
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      text: map['text'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  double _currentRating = 0;
  List<Comment> comments = [];

  final TextEditingController nameController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController imageController = TextEditingController();
  final TextEditingController ratingController = TextEditingController();
  final TextEditingController transmissionController = TextEditingController();
  final TextEditingController fuelTypeController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController featuresController =
      TextEditingController(); // updated
  final TextEditingController specificationsKeyController =
      TextEditingController();
  final TextEditingController specificationsValueController =
      TextEditingController();
  final TextEditingController topSpeedController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController commentsController = TextEditingController();

  Map<String, String> specifications = {};
  List<String> features = [];

  void _addSpecification() {
    if (specificationsKeyController.text.isNotEmpty &&
        specificationsValueController.text.isNotEmpty) {
      setState(() {
        specifications[specificationsKeyController.text] =
            specificationsValueController.text;
        specificationsKeyController.clear();
        specificationsValueController.clear();
      });
    }
  }

  void _addFeature() {
    if (featuresController.text.isNotEmpty) {
      setState(() {
        features.add(featuresController.text.trim());
        featuresController.clear();
      });
    }
  }

  Widget _buildRatingStars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < _currentRating ? Icons.star : Icons.star_border,
            color: index < _currentRating ? Colors.amber : Colors.grey,
            size: 30,
          ),
          onPressed: () {
            setState(() {
              _currentRating = index + 1;
            });
          },
        );
      }),
    );
  }

  Widget _buildCommentsList() {
    if (comments.isEmpty) {
      return const Center(child: Text('No comments yet'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(comment.text),
            subtitle: Row(
              children: [
                ...List.generate(5, (starIndex) {
                  return Icon(
                    starIndex < comment.rating ? Icons.star : Icons.star_border,
                    color:
                        starIndex < comment.rating ? Colors.amber : Colors.grey,
                    size: 20,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  comment.timestamp.toString().split('.')[0],
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editComment(index),
            ),
          ),
        );
      },
    );
  }

  void _editComment(int index) {
    final comment = comments[index];
    commentsController.text = comment.text;
    setState(() {
      _currentRating = comment.rating;
    });

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Comment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRatingStars(),
                TextField(
                  controller: commentsController,
                  decoration: const InputDecoration(labelText: 'Comment'),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  commentsController.clear();
                  setState(() {
                    _currentRating = 0;
                  });
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    comments[index] = Comment(
                      text: commentsController.text,
                      rating: _currentRating,
                      timestamp: DateTime.now(),
                    );
                  });
                  Navigator.pop(context);
                  commentsController.clear();
                  _currentRating = 0;
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _addComment() {
    if (commentsController.text.isNotEmpty && _currentRating > 0) {
      setState(() {
        comments.add(
          Comment(
            text: commentsController.text,
            rating: _currentRating,
            timestamp: DateTime.now(),
          ),
        );
        commentsController.clear();
        _currentRating = 0;
      });
    }
  }

  double get _averageRating {
    if (comments.isEmpty) return 0;
    return comments.map((c) => c.rating).reduce((a, b) => a + b) /
        comments.length;
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection('cars').add({
          'name': nameController.text.trim(),
          'brand': brandController.text.trim(),
          'price': int.parse(priceController.text.trim()),
          'image': imageController.text.trim(),
          'rating': double.parse(ratingController.text.trim()),
          'transmission': transmissionController.text.trim(),
          'fuelType': fuelTypeController.text.trim(),
          'latitude': double.parse(latitudeController.text.trim()),
          'longitude': double.parse(longitudeController.text.trim()),
          'description': descriptionController.text.trim(),
          'features': features, // updated
          'specifications': specifications,
          'topSpeed': topSpeedController.text.trim(),
          'category': categoryController.text.trim(),
          'comments': comments.map((c) => c.toMap()).toList(),
          'averageRating': _averageRating,
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle added successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    priceController.dispose();
    imageController.dispose();
    ratingController.dispose();
    transmissionController.dispose();
    fuelTypeController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    descriptionController.dispose();
    featuresController.dispose();
    specificationsKeyController.dispose();
    specificationsValueController.dispose();
    topSpeedController.dispose();
    categoryController.dispose();
    commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vehicle'),
        actions: [
          if (_averageRating > 0)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Text('Average Rating: '),
                  Text(
                    _averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.star, color: Colors.amber, size: 20),
                ],
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              TextFormField(
                controller: brandController,
                decoration: const InputDecoration(labelText: 'Brand'),
                validator: _required,
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: _required,
              ),
              TextFormField(
                controller: imageController,
                decoration: const InputDecoration(labelText: 'Image Path'),
                validator: _required,
              ),
              TextFormField(
                controller: ratingController,
                decoration: const InputDecoration(labelText: 'Rating'),
                keyboardType: TextInputType.number,
                validator: _required,
              ),
              TextFormField(
                controller: transmissionController,
                decoration: const InputDecoration(labelText: 'Transmission'),
                validator: _required,
              ),
              TextFormField(
                controller: fuelTypeController,
                decoration: const InputDecoration(labelText: 'Fuel Type'),
                validator: _required,
              ),
              TextFormField(
                controller: latitudeController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
                validator: _required,
              ),
              TextFormField(
                controller: longitudeController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
                validator: _required,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: _required,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: featuresController,
                      decoration: const InputDecoration(labelText: 'Feature'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addFeature,
                  ),
                ],
              ),
              Wrap(
                spacing: 6.0,
                children:
                    features
                        .map(
                          (f) => Chip(
                            label: Text(f),
                            onDeleted: () {
                              setState(() {
                                features.remove(f);
                              });
                            },
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: specificationsKeyController,
                      decoration: const InputDecoration(labelText: 'Spec Key'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: specificationsValueController,
                      decoration: const InputDecoration(
                        labelText: 'Spec Value',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addSpecification,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6.0,
                children:
                    specifications.entries.map((entry) {
                      return Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        onDeleted: () {
                          setState(() {
                            specifications.remove(entry.key);
                          });
                        },
                      );
                    }).toList(),
              ),

              TextFormField(
                controller: topSpeedController,
                decoration: const InputDecoration(labelText: 'Top Speed'),
                validator: _required,
              ),
              TextFormField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: _required,
              ),
              const SizedBox(height: 20),
              const Text(
                'Comments and Ratings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildRatingStars(),
              TextFormField(
                controller: commentsController,
                decoration: const InputDecoration(
                  labelText: 'Add a Comment (optional)',
                  hintText: 'Share your thoughts about this vehicle',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addComment,
                child: const Text('Add Comment'),
              ),
              const SizedBox(height: 20),
              _buildCommentsList(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Add Vehicle'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required field' : null;
  }
}
