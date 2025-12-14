import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_comment_screen.dart';

// Define sort options at top level
enum SortOption { newest, oldest, highestRating, lowestRating }

class VehicleCommentsScreen extends StatefulWidget {
  final String vehicleId;
  final bool hasRented;
  final bool isAdmin;

  const VehicleCommentsScreen({
    required this.vehicleId,
    required this.hasRented,
    this.isAdmin = false,
    Key? key,
  }) : super(key: key);

  @override
  State<VehicleCommentsScreen> createState() => _VehicleCommentsScreenState();
}

class _VehicleCommentsScreenState extends State<VehicleCommentsScreen> {
  int? _selectedRating;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Add sort option
  SortOption _currentSort = SortOption.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getSortOptionText(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return 'Newest First';
      case SortOption.oldest:
        return 'Oldest First';
      case SortOption.highestRating:
        return 'Highest Rating';
      case SortOption.lowestRating:
        return 'Lowest Rating';
    }
  }

  List<Map<String, dynamic>> _filterAndSortComments(
    List<Map<String, dynamic>> comments,
  ) {
    // First, filter the comments
    var filteredComments =
        comments.where((comment) {
          // Apply rating filter
          if (_selectedRating != null && comment['rating'] != _selectedRating) {
            return false;
          }

          // Apply case-insensitive search filter
          if (_searchQuery.isNotEmpty) {
            final searchLower = _searchQuery.toLowerCase();
            final text = comment['text']?.toString().toLowerCase() ?? '';
            final userName =
                comment['userName']?.toString().toLowerCase() ?? '';

            return text.contains(searchLower) || userName.contains(searchLower);
          }

          return true;
        }).toList();

    // Then, sort the filtered comments
    filteredComments.sort((a, b) {
      switch (_currentSort) {
        case SortOption.newest:
          return (b['timestamp'] as Timestamp).compareTo(
            a['timestamp'] as Timestamp,
          );
        case SortOption.oldest:
          return (a['timestamp'] as Timestamp).compareTo(
            b['timestamp'] as Timestamp,
          );
        case SortOption.highestRating:
          return (b['rating'] as num).compareTo(a['rating'] as num);
        case SortOption.lowestRating:
          return (a['rating'] as num).compareTo(b['rating'] as num);
      }
    });

    return filteredComments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews & Ratings')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Search Bar with case-insensitive hint
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search in reviews (case-insensitive)...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 16),
                // Sort Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SortOption>(
                      value: _currentSort,
                      isExpanded: true,
                      icon: const Icon(Icons.sort),
                      hint: const Text('Sort by'),
                      items:
                          SortOption.values.map((option) {
                            return DropdownMenuItem(
                              value: option,
                              child: Row(
                                children: [
                                  Icon(
                                    option == SortOption.newest ||
                                            option == SortOption.oldest
                                        ? Icons.access_time
                                        : Icons.star,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_getSortOptionText(option)),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (SortOption? newValue) {
                        if (newValue != null) {
                          setState(() => _currentSort = newValue);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Rating Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedRating == null,
                        onSelected: (selected) {
                          setState(() => _selectedRating = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(5, (index) {
                        final rating = index + 1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$rating'),
                                const Icon(Icons.star, size: 16),
                              ],
                            ),
                            selected: _selectedRating == rating,
                            onSelected: (selected) {
                              setState(
                                () =>
                                    _selectedRating = selected ? rating : null,
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('cars')
                      .doc(widget.vehicleId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final allComments = List<Map<String, dynamic>>.from(
                  data['comments'] ?? [],
                );
                final filteredComments = _filterAndSortComments(allComments);
                final averageRating = data['averageRating'] ?? 0.0;

                if (filteredComments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.comment_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allComments.isEmpty
                              ? 'No reviews yet'
                              : 'No reviews match your filters',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Average Rating: ${averageRating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star, color: Colors.amber),
                          Text(
                            ' (${filteredComments.length} reviews)',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredComments.length,
                        itemBuilder: (context, index) {
                          final comment = filteredComments[index];
                          final isCurrentUserComment =
                              comment['userId'] ==
                              FirebaseAuth.instance.currentUser?.uid;

                          String displayName;
                          if (widget.isAdmin || isCurrentUserComment) {
                            displayName = comment['userName'] ?? 'Anonymous';
                          } else {
                            displayName =
                                comment['showName'] == true
                                    ? comment['userName'] ?? 'Anonymous'
                                    : 'Anonymous User';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Row(
                                    children: [
                                      Text(displayName),
                                      if (!comment['showName'] &&
                                          (widget.isAdmin ||
                                              isCurrentUserComment))
                                        const Icon(
                                          Icons.visibility_off,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      const Spacer(),
                                      Text(
                                        DateTime.fromMillisecondsSinceEpoch(
                                          comment['timestamp']
                                              .millisecondsSinceEpoch,
                                        ).toString().split('.')[0],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: List.generate(
                                          5,
                                          (index) => Icon(
                                            index < (comment['rating'] ?? 0)
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(comment['text'] ?? ''),
                                    ],
                                  ),
                                  trailing:
                                      isCurrentUserComment
                                          ? IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed:
                                                () => _deleteComment(
                                                  context,
                                                  widget.vehicleId,
                                                  allComments.indexOf(comment),
                                                ),
                                          )
                                          : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (widget.hasRented)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _addComment(context, widget.vehicleId),
                child: const Text('Add Your Review'),
              ),
            ),
        ],
      ),
    );
  }

  void _deleteComment(BuildContext context, String vehicleId, int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Review'),
            content: const Text('Are you sure you want to delete your review?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final doc =
                        await FirebaseFirestore.instance
                            .collection('cars')
                            .doc(vehicleId)
                            .get();

                    final comments = List<Map<String, dynamic>>.from(
                      doc.data()?['comments'] ?? [],
                    );
                    comments.removeAt(index);

                    // Recalculate average rating
                    double averageRating = 0;
                    if (comments.isNotEmpty) {
                      final total = comments.fold<double>(
                        0,
                        (sum, comment) => sum + (comment['rating'] ?? 0),
                      );
                      averageRating = total / comments.length;
                    }

                    await FirebaseFirestore.instance
                        .collection('cars')
                        .doc(vehicleId)
                        .update({
                          'comments': comments,
                          'averageRating': averageRating,
                        });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting review: $e')),
                    );
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _addComment(BuildContext context, String vehicleId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCommentScreen(vehicleId: vehicleId),
      ),
    );
  }
}
