import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/screens/car_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  String? selectedBrand;
  String? selectedFuel;
  String? selectedTransmission;
  String? selectedSort;
  bool showFilters = false;
  final List<String> brands = [
    'All',
    'Porsche',
    'Maserati',
    'BMW',
    'Mercedes',
    'Tesla',
    'Honda',
    'Toyota',
    'Audi',
    'Hyundai',
    'Kia',
  ];
  final List<String> fuelTypes = [
    'All',
    'Petrol',
    'Diesel',
    'Electric',
    'Gasoline',
  ];
  final List<String> transmissions = ['All', 'Automatic', 'Manual'];
  final List<String> sortOptions = [
    'Most Booked',
    'Lowest Price',
    'Highest Price',
    '5 Stars',
    'Most Commented',
    'Most Favorites',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search cars...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildFilters(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children:
                sortOptions
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option),
                        selected: selectedSort == option,
                        onSelected: (selected) {
                          setState(() {
                            selectedSort = selected ? option : null;
                          });
                        },
                      ),
                    )
                    .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child:
              selectedSort == null &&
                      _searchController.text.isEmpty &&
                      (selectedBrand == null || selectedBrand == 'All') &&
                      (selectedFuel == null || selectedFuel == 'All') &&
                      (selectedTransmission == null ||
                          selectedTransmission == 'All')
                  ? _buildRecommendSection()
                  : _buildFilteredList(),
        ),
      ],
    );
  }

  Widget _buildRecommendSection() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('cars').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        docs.shuffle();
        final recommendDocs = docs.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Recommend',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recommendDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      recommendDocs[index].data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            data['image'] ?? '',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(data['name'] ?? ''),
                        subtitle: Text(
                          "${PriceFormatter.formatPrice((data['price'] ?? 0) is int ? (data['price'] ?? 0).toDouble() : (data['price'] ?? 0) as double)} / day",
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CarDetailScreen(
                                    carId: recommendDocs[index].id,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilteredList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('cars').snapshots(),
      builder: (context, carSnapshot) {
        if (!carSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        List<QueryDocumentSnapshot> docs = carSnapshot.data!.docs;
        // Filtering
        docs =
            docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name']?.toString().toLowerCase() ?? '';
              final brand = data['brand']?.toString().toLowerCase() ?? '';
              final fuel = data['fuelType'];
              final trans = data['transmission'];
              final searchText = _searchController.text.toLowerCase();
              final matchesSearch =
                  name.contains(searchText) || brand.contains(searchText);
              final matchesBrand =
                  selectedBrand == null ||
                  selectedBrand == 'All' ||
                  brand == selectedBrand?.toLowerCase();
              final matchesFuel =
                  selectedFuel == null ||
                  selectedFuel == 'All' ||
                  fuel == selectedFuel;
              final matchesTransmission =
                  selectedTransmission == null ||
                  selectedTransmission == 'All' ||
                  trans == selectedTransmission;
              return matchesSearch &&
                  matchesBrand &&
                  matchesFuel &&
                  matchesTransmission;
            }).toList();
        // Sorting/Filtering
        if (selectedSort != null) {
          if (selectedSort == 'Most Booked') {
            docs.sort((a, b) {
              final aCount =
                  (a.data() as Map<String, dynamic>)['bookingCount'] ?? 0;
              final bCount =
                  (b.data() as Map<String, dynamic>)['bookingCount'] ?? 0;
              return (bCount as num).compareTo(aCount as num);
            });
            docs = docs.take(5).toList();
          } else if (selectedSort == 'Lowest Price') {
            docs =
                docs.where((doc) {
                  final price = (doc['price'] ?? 0) as num;
                  return price >= 0 && price <= 4000;
                }).toList();
            docs.sort(
              (a, b) => ((a['price'] ?? 0) as num).compareTo(
                (b['price'] ?? 0) as num,
              ),
            );
          } else if (selectedSort == 'Highest Price') {
            docs =
                docs.where((doc) {
                  final price = (doc['price'] ?? 0) as num;
                  return price >= 10000 && price <= 40000;
                }).toList();
            docs.sort(
              (a, b) => ((b['price'] ?? 0) as num).compareTo(
                (a['price'] ?? 0) as num,
              ),
            );
          } else if (selectedSort == '5 Stars') {
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('comments').get(),
              builder: (context, commentSnapshot) {
                if (!commentSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allComments = commentSnapshot.data!.docs;
                final Map<String, List<double>> carRatings = {};

                // Calculate average ratings for each car
                for (var comment in allComments) {
                  final data = comment.data() as Map<String, dynamic>;
                  if (data.containsKey('carId') && data.containsKey('rating')) {
                    final carId = data['carId'] as String;
                    final rating = (data['rating'] as num).toDouble();
                    carRatings[carId] = [...(carRatings[carId] ?? []), rating];
                  }
                }

                // Filter cars with 5-star average rating
                final fiveStarCars =
                    docs.where((doc) {
                      final ratings = carRatings[doc.id] ?? [];
                      if (ratings.isEmpty) return false;
                      final averageRating =
                          ratings.reduce((a, b) => a + b) / ratings.length;
                      return averageRating == 5.0;
                    }).toList();

                if (fiveStarCars.isEmpty) {
                  return const Center(
                    child: Text("No 5-star rated cars found."),
                  );
                }

                return ListView.builder(
                  itemCount: fiveStarCars.length,
                  itemBuilder: (context, index) {
                    final data =
                        fiveStarCars[index].data() as Map<String, dynamic>;
                    final ratings = carRatings[fiveStarCars[index].id] ?? [];
                    final averageRating =
                        ratings.isEmpty
                            ? 0.0
                            : ratings.reduce((a, b) => a + b) / ratings.length;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['image'] ?? '',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(data['name'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${PriceFormatter.formatPrice((data['price'] ?? 0) is int ? (data['price'] ?? 0).toDouble() : (data['price'] ?? 0) as double)} / day",
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  Text(
                                    " ${averageRating.toStringAsFixed(1)} (${ratings.length} reviews)",
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CarDetailScreen(
                                      carId: fiveStarCars[index].id,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          } else if (selectedSort == 'Most Commented') {
            // Fetch all comments and count per car
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('comments').get(),
              builder: (context, commentSnapshot) {
                if (!commentSnapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final allComments = commentSnapshot.data!.docs;
                // Map carId to comment count
                final Map<String, int> commentCounts = {};
                for (var comment in allComments) {
                  final data = comment.data() as Map<String, dynamic>;
                  if (data.containsKey('carId')) {
                    final carId = data['carId'] as String;
                    commentCounts[carId] = (commentCounts[carId] ?? 0) + 1;
                  }
                }
                // Sort cars by comment count
                docs.sort((a, b) {
                  final aCount = commentCounts[a.id] ?? 0;
                  final bCount = commentCounts[b.id] ?? 0;
                  return bCount.compareTo(aCount);
                });
                docs = docs.take(10).toList();
                if (docs.isEmpty)
                  return const Center(child: Text("No cars found."));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['image'] ?? '',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(data['name'] ?? ''),
                          subtitle: Text(
                            "${PriceFormatter.formatPrice((data['price'] ?? 0) is int ? (data['price'] ?? 0).toDouble() : (data['price'] ?? 0) as double)} / day",
                          ),
                          trailing: Text(
                            '${commentCounts[docs[index].id] ?? 0} comments',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        CarDetailScreen(carId: docs[index].id),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          } else if (selectedSort == 'Most Favorites') {
            // Fetch all favorites and count per car
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('favorites').get(),
              builder: (context, favSnapshot) {
                if (!favSnapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final allFavorites = favSnapshot.data!.docs;
                // Map carId to favorite count
                final Map<String, int> favoriteCounts = {};
                for (var fav in allFavorites) {
                  final data = fav.data() as Map<String, dynamic>;
                  if (data.containsKey('carId')) {
                    final carId = data['carId'] as String;
                    favoriteCounts[carId] = (favoriteCounts[carId] ?? 0) + 1;
                  }
                }
                // Sort cars by favorite count
                docs.sort((a, b) {
                  final aCount = favoriteCounts[a.id] ?? 0;
                  final bCount = favoriteCounts[b.id] ?? 0;
                  return bCount.compareTo(aCount);
                });
                docs = docs.take(10).toList();
                if (docs.isEmpty)
                  return const Center(child: Text("No cars found."));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['image'] ?? '',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(data['name'] ?? ''),
                          subtitle: Text(
                            "${PriceFormatter.formatPrice((data['price'] ?? 0) is int ? (data['price'] ?? 0).toDouble() : (data['price'] ?? 0) as double)} / day",
                          ),
                          trailing: Text(
                            '${favoriteCounts[docs[index].id] ?? 0} favorites',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        CarDetailScreen(carId: docs[index].id),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        }
        if (docs.isEmpty) return const Center(child: Text("No cars found."));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      data['image'] ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(data['name'] ?? ''),
                  subtitle: Text(
                    "${PriceFormatter.formatPrice((data['price'] ?? 0) is int ? (data['price'] ?? 0).toDouble() : (data['price'] ?? 0) as double)} / day",
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CarDetailScreen(carId: docs[index].id),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _dropdown("Brand", brands, selectedBrand, (value) {
            setState(() {
              selectedBrand = value;
            });
          }),
          _dropdown("Fuel", fuelTypes, selectedFuel, (value) {
            setState(() {
              selectedFuel = value;
            });
          }),
          _dropdown("Transmission", transmissions, selectedTransmission, (
            value,
          ) {
            setState(() {
              selectedTransmission = value;
            });
          }),
        ],
      ),
    );
  }

  Widget _dropdown(
    String hint,
    List<String> items,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButton<String>(
      value: selected ?? 'All',
      hint: Text(hint),
      onChanged: onChanged,
      items:
          items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
    );
  }
}
