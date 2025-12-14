import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/colors.dart';
import 'package:intl/intl.dart';

class CorporateRentalManagementScreen extends StatefulWidget {
  const CorporateRentalManagementScreen({super.key});

  @override
  State<CorporateRentalManagementScreen> createState() =>
      _CorporateRentalManagementScreenState();
}

class _CorporateRentalManagementScreenState
    extends State<CorporateRentalManagementScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  final DateFormat dateFormat = DateFormat('MMM dd, yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corporate Rentals'),
        backgroundColor: AppColors.primary,
        // Removed refresh button, stream builder handles updates
        // actions: [
        //   IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBookings),
        // ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search by Car Name or Brand',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery =
                      value.toLowerCase(); // Search is case-insensitive
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items:
                        ['All', 'active', 'upcoming', 'completed', 'cancelled']
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.toUpperCase()),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final DateTimeRange? dateRange =
                          await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ), // Allow selecting future dates
                            initialDateRange:
                                _startDate != null && _endDate != null
                                    ? DateTimeRange(
                                      start: _startDate!,
                                      end: _endDate!,
                                    )
                                    : null,
                          );
                      if (dateRange != null) {
                        setState(() {
                          _startDate = dateRange.start;
                          _endDate = dateRange.end;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}'
                          : 'Select Date Range',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 0.0,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear Date Filter'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredBookings =
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final carName =
                          data['carName']?.toString().toLowerCase() ?? '';
                      final carBrand =
                          data['carBrand']?.toString().toLowerCase() ??
                          ''; // Assuming 'carBrand' field exists

                      // Apply search query filter locally
                      if (_searchQuery.isNotEmpty &&
                          !carName.contains(_searchQuery) &&
                          !carBrand.contains(_searchQuery)) {
                        return false;
                      }

                      return true;
                    }).toList();

                if (filteredBookings.isEmpty) {
                  return const Center(
                    child: Text('No corporate rentals found'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking =
                        filteredBookings[index].data() as Map<String, dynamic>;
                    final bookingId = filteredBookings[index].id;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(booking['carName'] ?? 'Unknown Car'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Company: ${booking['companyName'] ?? 'N/A'}'),
                            Text(
                              'Dates: ${DateFormat('MMM dd, yyyy').format((booking['startDate'] as Timestamp).toDate())} - ${DateFormat('MMM dd, yyyy').format((booking['endDate'] as Timestamp).toDate())}',
                            ),
                            Text('Quantity: ${booking['quantity'] ?? 1}'),
                            Text(
                              'Total: ${booking['totalAmount']?.toStringAsFixed(2) ?? 'N/A'} ₺',
                            ),
                            Text(
                              'Status: ${booking['status']?.toUpperCase() ?? 'N/A'}',
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  value: 'view',
                                  child: const Text('View Details'),
                                ),
                                if (booking['status'] == 'active' ||
                                    booking['status'] == 'upcoming')
                                  PopupMenuItem(
                                    value: 'cancel',
                                    child: const Text('Cancel Booking'),
                                  ),
                                if (booking['status'] == 'active')
                                  PopupMenuItem(
                                    value: 'complete',
                                    child: const Text('Mark as Completed'),
                                  ),
                              ],
                          onSelected: (value) async {
                            switch (value) {
                              case 'view':
                                Navigator.pushNamed(
                                  context,
                                  '/rental_detail',
                                  arguments: bookingId,
                                );
                                break;
                              case 'cancel':
                                final shouldCancel = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Cancel Booking'),
                                        content: const Text(
                                          'Are you sure you want to cancel this booking?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('No'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text('Yes'),
                                          ),
                                        ],
                                      ),
                                );

                                if (shouldCancel == true) {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('bookings')
                                        .doc(bookingId)
                                        .update({
                                          'status': 'cancelled',
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                    // No need to call _loadBookings(), stream handles updates
                                  } catch (e) {
                                    print('Error cancelling booking: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error cancelling booking: $e',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                                break;
                              case 'complete':
                                final shouldComplete = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Complete Booking'),
                                        content: const Text(
                                          'Are you sure you want to mark this booking as completed?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('No'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text('Yes'),
                                          ),
                                        ],
                                      ),
                                );

                                if (shouldComplete == true) {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('bookings')
                                        .doc(bookingId)
                                        .update({
                                          'status': 'completed',
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                    // No need to call _loadBookings(), stream handles updates
                                  } catch (e) {
                                    print('Error completing booking: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error completing booking: $e',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                                break;
                            }
                          },
                        ),
                      ),
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

  Stream<QuerySnapshot> _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('bookings')
        .where('isCorporate', isEqualTo: true)
        .orderBy(
          'startDate',
          descending: true,
        ); // Order by start date initially

    if (_selectedStatus != 'All') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    if (_startDate != null && _endDate != null) {
      // Add 23 hours, 59 minutes, 59 seconds to the end date to include the whole day
      final endDateInclusive = _endDate!.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      query = query.where(
        'startDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
        isLessThanOrEqualTo: Timestamp.fromDate(endDateInclusive),
      );
    }

    // Note: Firestore doesn't support querying by partial string match (like contains) directly.
    // We will apply the search filter locally after fetching the data.
    // If performance becomes an issue with a very large number of corporate bookings,
    // we might need to consider alternative solutions like a dedicated search service (e.g., Algolia).

    return query.snapshots();
  }
}
