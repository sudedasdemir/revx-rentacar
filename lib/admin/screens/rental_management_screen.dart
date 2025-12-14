import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app/services/notification_service.dart';

class RentalManagementScreen extends StatefulWidget {
  final String? initialBookingId;

  const RentalManagementScreen({Key? key, this.initialBookingId})
    : super(key: key);

  @override
  State<RentalManagementScreen> createState() => _RentalManagementScreenState();
}

class _RentalManagementScreenState extends State<RentalManagementScreen> {
  final CollectionReference bookingsRef = FirebaseFirestore.instance.collection(
    'bookings',
  );
  final TextEditingController searchController = TextEditingController();
  String selectedStatus = 'All';
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  String searchQuery = '';
  String? _currentFilterBookingId;

  @override
  void initState() {
    super.initState();
    if (widget.initialBookingId != null) {
      searchController.text = widget.initialBookingId!;
      searchQuery = widget.initialBookingId!;
      _currentFilterBookingId = widget.initialBookingId!;
      print(
        'RentalManagementScreen received initialBookingId: ${widget.initialBookingId}',
      );
    }
  }

  final List<String> statusOptions = [
    'All',
    'upcoming',
    'ongoing',
    'completed',
    'cancelled',
  ];

  // Araç bilgilerini almak için method
  Future<Map<String, dynamic>> _getCarDetails(String? carId) async {
    if (carId == null || carId.isEmpty) {
      print('Warning: Invalid car ID provided');
      return {'error': 'Invalid car ID'};
    }

    try {
      final carDoc =
          await FirebaseFirestore.instance.collection('cars').doc(carId).get();

      if (!carDoc.exists) {
        return {'error': 'Car not found'};
      }

      return carDoc.data() ?? {};
    } catch (e) {
      print('Error fetching car details: $e');
      return {'error': 'Failed to fetch car details'};
    }
  }

  // Kullanıcı bilgilerini almak için method
  Future<Map<String, dynamic>> _getUserDetails(String? userId) async {
    if (userId == null || userId.isEmpty) {
      print('Warning: Invalid user ID provided');
      return {'error': 'Invalid user ID'};
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (!userDoc.exists) {
        return {'error': 'User not found'};
      }

      return userDoc.data() ?? {};
    } catch (e) {
      print('Error fetching user details: $e');
      return {'error': 'Failed to fetch user details'};
    }
  }

  // Araç ve kullanıcı bilgilerini birleştirerek döndürme methodu
  Future<Map<String, dynamic>> _fetchDetails(Map<String, dynamic> data) async {
    if (!data.containsKey('carId') || !data.containsKey('userId')) {
      return {
        'car': {'error': 'Missing required IDs'},
        'user': {'error': 'Missing required IDs'},
      };
    }

    final car = await _getCarDetails(data['carId'] as String?);
    final user = await _getUserDetails(data['userId'] as String?);
    return {'car': car, 'user': user};
  }

  // Cancel işlemi: booking ve payment status güncelleme
  Future<void> _cancelBookingAndPayment(String bookingId) async {
    final bookingDoc =
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get();

    if (!bookingDoc.exists) return;

    final data = bookingDoc.data()!;
    final paymentId = data['paymentId'] as String?;
    final userId = data['userId'] as String?;
    final carName = data['carName'] as String?;

    // bookings status güncelle
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'status': 'cancelled'});

    // payments status güncelle (varsa)
    if (paymentId != null && paymentId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({'status': 'cancelled'});
    }

    // Send notification to user
    if (userId != null) {
      await NotificationService().sendNotification(
        title: 'Rental Cancelled',
        body: 'Your rental for ${carName ?? 'the car'} has been cancelled.',
        userId: userId,
      );
    }
  }

  // Diğer statusler için güncelleme
  Future<void> _updateStatus(String bookingId, String newStatus) async {
    try {
      await bookingsRef.doc(bookingId).update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Select Date Range
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          selectedStartDate != null && selectedEndDate != null
              ? DateTimeRange(start: selectedStartDate!, end: selectedEndDate!)
              : null,
    );
    if (picked != null &&
        (picked.start != selectedStartDate || picked.end != selectedEndDate)) {
      setState(() {
        selectedStartDate = picked.start;
        selectedEndDate = picked.end;
      });
    }
  }

  // Clear filters
  void _clearFilters() {
    setState(() {
      searchController.clear();
      searchQuery = '';
      selectedStatus = 'All';
      selectedStartDate = null;
      selectedEndDate = null;
      _currentFilterBookingId = null;
    });
  }

  String _getDateRangeText() {
    if (selectedStartDate == null || selectedEndDate == null) {
      return 'Filter by Date Range';
    }
    return '${DateFormat('yyyy-MM-dd').format(selectedStartDate!)} - ${DateFormat('yyyy-MM-dd').format(selectedEndDate!)}';
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rental Management'), centerTitle: true),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by car name, brand or booking ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  searchController.clear();
                                  searchQuery = '';
                                  _currentFilterBookingId = null;
                                });
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      _currentFilterBookingId = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Filters Row
                Row(
                  children: [
                    // Date Range Filter
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectDateRange(context),
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _getDateRangeText(),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Status Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        items:
                            statusOptions.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status.toUpperCase()),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedStatus = value;
                              _currentFilterBookingId = null;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Clear Filters Button
                if (searchQuery.isNotEmpty ||
                    selectedStatus != 'All' ||
                    selectedStartDate != null ||
                    _currentFilterBookingId != null)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Filters'),
                  ),
              ],
            ),
          ),
          // Bookings List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: bookingsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(child: Text('Error loading rentals.'));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final bookings = snapshot.data!.docs;

                if (bookings.isEmpty) {
                  return const Center(child: Text('No bookings found.'));
                }

                // Filter bookings based on initialBookingId, then other filters
                final filteredBookings =
                    bookings.where((booking) {
                      final data = booking.data() as Map<String, dynamic>;
                      final bookingId = booking.id.toLowerCase();

                      if (_currentFilterBookingId != null) {
                        return bookingId ==
                            _currentFilterBookingId!.toLowerCase();
                      }

                      // Status filter
                      if (selectedStatus != 'All' &&
                          data['status'] != selectedStatus) {
                        return false;
                      }

                      // Date range filter
                      if (selectedStartDate != null &&
                          selectedEndDate != null) {
                        final startDate =
                            (data['startDate'] as Timestamp).toDate();
                        final endDate = (data['endDate'] as Timestamp).toDate();

                        // Check if the rental period overlaps with the selected date range
                        final rentalStart = DateTime(
                          startDate.year,
                          startDate.month,
                          startDate.day,
                        );
                        final rentalEnd = DateTime(
                          endDate.year,
                          endDate.month,
                          endDate.day,
                        );
                        final filterStart = DateTime(
                          selectedStartDate!.year,
                          selectedStartDate!.month,
                          selectedStartDate!.day,
                        );
                        final filterEnd = DateTime(
                          selectedEndDate!.year,
                          selectedEndDate!.month,
                          selectedEndDate!.day,
                        ).add(
                          const Duration(days: 1),
                        ); // Add one day to include the end date

                        if (!(rentalStart.isBefore(filterEnd) &&
                            rentalEnd.isAfter(filterStart))) {
                          return false;
                        }
                      }

                      // Search filter (only applies if no initialBookingId)
                      return bookingId.contains(searchQuery.toLowerCase());
                    }).toList();

                if (filteredBookings.isEmpty) {
                  return const Center(
                    child: Text('No matching bookings found.'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    final data = booking.data() as Map<String, dynamic>;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _fetchDetails(data),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const ListTile(title: Text('Loading...'));

                        final car = snapshot.data!['car'];
                        final user = snapshot.data!['user'];

                        // Get payment details
                        final paymentId = data['paymentId'] as String?;
                        double totalAmount = 0.0;
                        double voucherAmount = 0.0;
                        double finalAmount = 0.0;

                        if (paymentId != null && paymentId.isNotEmpty) {
                          return FutureBuilder<DocumentSnapshot>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('payments')
                                    .doc(paymentId)
                                    .get(),
                            builder: (context, paymentSnapshot) {
                              if (paymentSnapshot.hasData &&
                                  paymentSnapshot.data!.exists) {
                                final paymentData =
                                    paymentSnapshot.data!.data()
                                        as Map<String, dynamic>;
                                totalAmount =
                                    (paymentData['amount'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                voucherAmount =
                                    (paymentData['voucherAmount'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                finalAmount =
                                    (paymentData['finalAmount'] as num?)
                                        ?.toDouble() ??
                                    totalAmount;
                              } else {
                                // Fallback to booking data if payment not found
                                totalAmount =
                                    (data['totalAmount'] as num?)?.toDouble() ??
                                    0.0;
                                voucherAmount =
                                    (data['voucherAmount'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                finalAmount =
                                    (data['finalAmount'] as num?)?.toDouble() ??
                                    totalAmount;
                              }

                              return Card(
                                margin: const EdgeInsets.all(12),
                                child: ListTile(
                                  title: Text(
                                    car['error'] ??
                                        '${car['brand']} ${car['name']}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Renter: ${user['error'] ?? user['name'] ?? user['email'] ?? 'N/A'}',
                                      ),
                                      if (data['startDate'] != null)
                                        Text(
                                          'Start: ${DateFormat('yyyy-MM-dd HH:mm').format((data['startDate'] as Timestamp).toDate())}',
                                        ),
                                      if (data['endDate'] != null)
                                        Text(
                                          'End: ${DateFormat('yyyy-MM-dd HH:mm').format((data['endDate'] as Timestamp).toDate())}',
                                        ),
                                      Text(
                                        'Original Price: ${PriceFormatter.formatPrice(totalAmount)}',
                                      ),
                                      if (voucherAmount > 0)
                                        Text(
                                          'Voucher Applied: ${PriceFormatter.formatPrice(voucherAmount)}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                          ),
                                        ),
                                      Text(
                                        'Final Amount Paid: ${PriceFormatter.formatPrice(finalAmount)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Status: ${data['status'] ?? 'N/A'}',
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected:
                                        (value) =>
                                            _updateStatus(booking.id, value),
                                    itemBuilder:
                                        (context) => [
                                          const PopupMenuItem(
                                            value: 'upcoming',
                                            child: Text('Upcoming'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'ongoing',
                                            child: Text('Ongoing'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'completed',
                                            child: Text('Completed'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'cancelled',
                                            child: Text('Cancelled'),
                                          ),
                                        ],
                                    child: const Icon(Icons.more_vert),
                                  ),
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/rental_detail',
                                      arguments: booking.id,
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        } else {
                          // If no payment ID, use booking data
                          totalAmount =
                              (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                          voucherAmount =
                              (data['voucherAmount'] as num?)?.toDouble() ??
                              0.0;
                          finalAmount =
                              (data['finalAmount'] as num?)?.toDouble() ??
                              totalAmount;

                          return Card(
                            margin: const EdgeInsets.all(12),
                            child: ListTile(
                              title: Text(
                                car['error'] ??
                                    '${car['brand']} ${car['name']}',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Renter: ${user['error'] ?? user['name'] ?? user['email'] ?? 'N/A'}',
                                  ),
                                  if (data['startDate'] != null)
                                    Text(
                                      'Start: ${DateFormat('yyyy-MM-dd HH:mm').format((data['startDate'] as Timestamp).toDate())}',
                                    ),
                                  if (data['endDate'] != null)
                                    Text(
                                      'End: ${DateFormat('yyyy-MM-dd HH:mm').format((data['endDate'] as Timestamp).toDate())}',
                                    ),
                                  Text(
                                    'Original Price: ${PriceFormatter.formatPrice(totalAmount)}',
                                  ),
                                  if (voucherAmount > 0)
                                    Text(
                                      'Voucher Applied: ${PriceFormatter.formatPrice(voucherAmount)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                                  Text(
                                    'Final Amount Paid: ${PriceFormatter.formatPrice(finalAmount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('Status: ${data['status'] ?? 'N/A'}'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected:
                                    (value) => _updateStatus(booking.id, value),
                                itemBuilder:
                                    (context) => [
                                      const PopupMenuItem(
                                        value: 'upcoming',
                                        child: Text('Upcoming'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'ongoing',
                                        child: Text('Ongoing'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'completed',
                                        child: Text('Completed'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'cancelled',
                                        child: Text('Cancelled'),
                                      ),
                                    ],
                                child: const Icon(Icons.more_vert),
                              ),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/rental_detail',
                                  arguments: booking.id,
                                );
                              },
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
