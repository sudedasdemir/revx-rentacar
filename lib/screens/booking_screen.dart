import 'package:firebase_app/widgets/booking_calendar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app/car_model.dart';
import 'package:firebase_app/colors.dart';
import 'payment_screen.dart';
import 'package:firebase_app/theme/theme.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:firebase_app/services/notification_service.dart';
import 'dart:math' show min;

class BookingScreen extends StatefulWidget {
  final Car car;

  const BookingScreen({Key? key, required this.car}) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // Store ancestor references
  late final inheritedTheme;

  DateTime? pickupDateTime;
  DateTime? returnDateTime;
  final TextEditingController pickupDateController = TextEditingController();
  final TextEditingController returnDateController = TextEditingController();

  String? pickupLocation;
  String? returnLocation;

  bool addInsurance = false;
  bool addChildSeat = false;

  List<String> availableLocations = [
    'Istanbul Airport',
    'Sabiha Gokcen',
    'Ankara',
    'Izmir',
  ];

  List<DateTime> bookedDates = [];
  bool isLoading = true;

  // Add new state variables
  bool isCorporateUser = false;
  int selectedQuantity = 1;
  int availableStock = 0;
  List<Map<String, dynamic>> driverLicenses = [];
  bool isLoadingDriverLicenses = false;

  String _formatDateInput(String input) {
    // Remove any non-digit characters
    String digits = input.replaceAll(RegExp(r'[^\d]'), '');

    // Format the date as we type
    if (digits.length > 4) {
      return '${digits.substring(0, 4)}-${digits.substring(4, min(6, digits.length))}${digits.length > 6 ? '-${digits.substring(6, min(8, digits.length))}' : ''}';
    } else if (digits.length > 0) {
      return digits;
    }
    return '';
  }

  void _handleDateInput(String value, bool isPickup) {
    final formattedDate = _formatDateInput(value);
    if (isPickup) {
      pickupDateController.text = formattedDate;
      pickupDateController.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedDate.length),
      );
    } else {
      returnDateController.text = formattedDate;
      returnDateController.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedDate.length),
      );
    }

    // Try to parse the date if it's complete
    if (formattedDate.length == 10) {
      final date = DateTime.tryParse(formattedDate);
      if (date != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        if (isPickup) {
          if (date.isBefore(today)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pickup date cannot be in the past.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            if (isPickup) pickupDateController.clear();
            setState(() => pickupDateTime = null);
            return; // Stop processing if date is invalid
          }
        } else {
          // isReturn
          if (pickupDateTime != null && date.isBefore(pickupDateTime!)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Return date cannot be before pickup date.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            if (!isPickup) returnDateController.clear();
            setState(() => returnDateTime = null);
            return; // Stop processing if date is invalid
          }
        }

        setState(() {
          if (isPickup) {
            pickupDateTime = date;
          } else {
            returnDateTime = date;
          }
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save references to ancestors when dependencies change
    inheritedTheme =
        context.dependOnInheritedWidgetOfExactType<InheritedTheme>();
  }

  // Use saved reference instead of looking it up in dispose
  @override
  void dispose() {
    pickupDateController.dispose();
    returnDateController.dispose();
    // Use inheritedTheme here if needed
    super.dispose();
  }

  Future<List<DateTime>> getDisabledDatesForCar(String carId) async {
    try {
      // Get all active bookings for this specific car
      final bookingsSnapshot =
          await FirebaseFirestore.instance
              .collection('bookings')
              .where('carId', isEqualTo: carId)
              .where(
                'status',
                whereIn: ['active', 'ongoing', 'upcoming', 'confirmed'],
              )
              .get();

      Set<DateTime> disabledDates = {};

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        DateTime start = (data['startDate'] as Timestamp).toDate();
        DateTime end = (data['endDate'] as Timestamp).toDate();

        // Add all dates between start and end to disabled dates
        for (
          DateTime date = start;
          date.isBefore(end.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))
        ) {
          final normalizedDate = DateTime(date.year, date.month, date.day);
          disabledDates.add(normalizedDate);
        }
      }

      final sortedDates = disabledDates.toList()..sort();
      print(
        'Disabled dates for car ${carId}: ${sortedDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).join(', ')}',
      );
      return sortedDates;
    } catch (e) {
      print('Error fetching disabled dates for car $carId: $e');
      return [];
    }
  }

  Future<bool> isDateRangeAvailable(DateTime start, DateTime end) async {
    try {
      if (isCorporateUser) {
        // For corporate users, check stock availability
        final carDoc =
            await FirebaseFirestore.instance
                .collection('cars')
                .doc(widget.car.id)
                .get();

        if (!carDoc.exists) {
          throw Exception('Car not found');
        }

        final carData = carDoc.data() as Map<String, dynamic>;
        final stock = (carData['stock'] ?? 0) as int;

        if (stock < selectedQuantity) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Only $stock vehicles available in stock'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        // Check existing corporate bookings for the date range
        final bookingsSnapshot =
            await FirebaseFirestore.instance
                .collection('bookings')
                .where('carId', isEqualTo: widget.car.id)
                .where(
                  'status',
                  whereIn: ['active', 'ongoing', 'upcoming', 'confirmed'],
                )
                .get();

        int bookedCount = 0;
        for (var doc in bookingsSnapshot.docs) {
          final data = doc.data();
          final bookedStart = (data['startDate'] as Timestamp).toDate();
          final bookedEnd = (data['endDate'] as Timestamp).toDate();

          if (start.isBefore(bookedEnd) && end.isAfter(bookedStart)) {
            bookedCount += (data['quantity'] ?? 1) as int;
          }
        }

        if (bookedCount + selectedQuantity > stock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Only ${stock - bookedCount} vehicles available for selected dates',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      } else {
        // First check if the car is in maintenance
        final carDoc =
            await FirebaseFirestore.instance
                .collection('cars')
                .doc(widget.car.id)
                .get();

        if (!carDoc.exists) {
          throw Exception('Car not found');
        }

        final carData = carDoc.data() as Map<String, dynamic>;
        if (carData['isInMaintenance'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This vehicle is currently under maintenance and cannot be rented',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        // Normalize dates to UTC to avoid timezone issues
        final utcStart = DateTime.utc(start.year, start.month, start.day);
        final utcEnd = DateTime.utc(end.year, end.month, end.day);

        // Get all bookings that might overlap with the selected date range
        final bookingsSnapshot =
            await FirebaseFirestore.instance
                .collection('bookings')
                .where('carId', isEqualTo: widget.car.id)
                .where(
                  'status',
                  whereIn: ['active', 'ongoing', 'upcoming', 'confirmed'],
                )
                .get();

        for (var doc in bookingsSnapshot.docs) {
          final data = doc.data();
          final bookedStart = (data['startDate'] as Timestamp).toDate();
          final bookedEnd = (data['endDate'] as Timestamp).toDate();

          // Normalize booked dates to UTC
          final utcBookedStart = DateTime.utc(
            bookedStart.year,
            bookedStart.month,
            bookedStart.day,
          );
          final utcBookedEnd = DateTime.utc(
            bookedEnd.year,
            bookedEnd.month,
            bookedEnd.day,
          );

          // Check if the date ranges overlap
          if (utcStart.isBefore(utcBookedEnd) &&
              utcEnd.isAfter(utcBookedStart)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'This car is already booked from ${DateFormat('MMM dd').format(bookedStart)} to ${DateFormat('MMM dd').format(bookedEnd)}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print('Error checking date range availability: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to verify availability. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _isCarAlreadyBookedByUser(DateTime start, DateTime end) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      final bookingsSnapshot =
          await FirebaseFirestore.instance
              .collection('bookings')
              .where('carId', isEqualTo: widget.car.id)
              .where('userId', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'active')
              .get();

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final bookedStart = (data['startDate'] as Timestamp).toDate();
        final bookedEnd = (data['endDate'] as Timestamp).toDate();

        // Check if dates overlap
        if (start.isBefore(bookedEnd) && end.isAfter(bookedStart)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking user bookings: $e');
      return false;
    }
  }

  Future<void> _fetchBookedDates() async {
    try {
      setState(() => isLoading = true);

      final dates = await getDisabledDatesForCar(widget.car.id);

      if (mounted) {
        setState(() {
          bookedDates = dates;
          isLoading = false;
        });
      }

      print(
        'Booked dates for car ${widget.car.id}: ${bookedDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).join(', ')}',
      );
    } catch (e) {
      print('Error fetching booked dates: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchBookedDates();
    _checkUserType();
    _loadAvailableStock();
  }

  Future<void> _checkUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (mounted) {
        setState(() {
          isCorporateUser = userDoc.data()?['isCorporate'] ?? false;
        });
      }
    }
  }

  Future<void> _loadAvailableStock() async {
    final carDoc =
        await FirebaseFirestore.instance
            .collection('cars')
            .doc(widget.car.id)
            .get();

    if (mounted) {
      setState(() {
        availableStock = carDoc.data()?['stock'] ?? 0;
      });
    }
  }

  Future<void> _loadDriverLicenses() async {
    if (!isCorporateUser) return;

    setState(() => isLoadingDriverLicenses = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final licensesSnapshot =
            await FirebaseFirestore.instance
                .collection('driver_licenses')
                .where('userId', isEqualTo: user.uid)
                .get();

        if (mounted) {
          setState(() {
            driverLicenses =
                licensesSnapshot.docs
                    .map((doc) => {'id': doc.id, ...doc.data()})
                    .toList();
            isLoadingDriverLicenses = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => isLoadingDriverLicenses = false);
        }
      }
    } catch (e) {
      print('Error loading driver licenses: $e');
      if (mounted) {
        setState(() => isLoadingDriverLicenses = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>?> _showDriverLicenseDialog() async {
    // Ensure licenses are loaded before showing the dialog
    await _loadDriverLicenses();

    // Create a local copy of driverLicenses for the dialog to modify
    List<Map<String, dynamic>> dialogDriverLicenses = List.from(driverLicenses);

    final result = await showDialog<List<Map<String, dynamic>>>(
      // Explicitly cast result type
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Manage Driver Licenses'),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'You need to select ${dialogDriverLicenses.where((license) => license['selected'] == true).length}/$selectedQuantity driver license(s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Note: Drivers must have at least 2 years of experience',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        // Display loading indicator if data is still loading
                        if (isLoadingDriverLicenses)
                          const Center(child: CircularProgressIndicator())
                        else if (dialogDriverLicenses.isEmpty)
                          const Text('No driver licenses found')
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dialogDriverLicenses.length,
                            itemBuilder: (context, index) {
                              final license = dialogDriverLicenses[index];
                              final expiryDate =
                                  (license['expiryDate'] as Timestamp).toDate();
                              final issueDate =
                                  (license['issueDate'] as Timestamp).toDate();
                              final yearsOfExperience =
                                  DateTime.now().difference(issueDate).inDays /
                                  365;
                              final isEligible = yearsOfExperience >= 2;

                              return ListTile(
                                title: Text(
                                  license['name'] ?? 'Unknown Driver',
                                ),
                                subtitle: Text(
                                  'License: ${license['licenseNumber'] ?? 'N/A'}'
                                  ' | Expires: ${DateFormat('MM/yy').format(expiryDate)}'
                                  ' | Experience: ${yearsOfExperience.toStringAsFixed(1)} yrs',
                                  style: TextStyle(
                                    color:
                                        isEligible ? Colors.green : Colors.red,
                                  ),
                                ),
                                leading: Checkbox(
                                  value: license['selected'] ?? false,
                                  onChanged:
                                      isEligible
                                          ? (value) {
                                            // Count currently selected licenses
                                            final selectedCount =
                                                dialogDriverLicenses
                                                    .where(
                                                      (l) =>
                                                          l['selected'] == true,
                                                    )
                                                    .length;

                                            // If trying to select more than needed, show error
                                            if (value == true &&
                                                selectedCount >=
                                                    selectedQuantity) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'You can only select $selectedQuantity license(s)',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            // Update the local list within the dialog's setState
                                            setState(() {
                                              license['selected'] = value;
                                            });
                                          }
                                          : null,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await _deleteDriverLicense(
                                      license['id'],
                                    ); // Delete and refresh main state
                                    setState(() {
                                      // Update dialog's local copy after deletion
                                      dialogDriverLicenses.removeWhere(
                                        (l) => l['id'] == license['id'],
                                      );
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // Pop the current dialog
                            await Navigator.pushNamed(
                              context,
                              '/add-driver-license',
                            );
                            await _loadDriverLicenses(); // Reload licenses for the main state
                          },
                          child: const Text('Add New License'),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, null); // Return null on close
                    },
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        dialogDriverLicenses,
                      ); // Return updated list on save
                    },
                    child: const Text('Save Selection'),
                  ),
                ],
              );
            },
          ),
    );
    return result; // Return the result from showDialog
  }

  Future<void> _deleteDriverLicense(String licenseId) async {
    // Removed StateSetter
    try {
      await FirebaseFirestore.instance
          .collection('driver_licenses')
          .doc(licenseId)
          .delete();
      // Update the main state after deletion
      await _loadDriverLicenses(); // Refresh main list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver license deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting driver license: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting license: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isDateBooked(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return bookedDates.any((bookedDate) {
      final normalizedBookedDate = DateTime(
        bookedDate.year,
        bookedDate.month,
        bookedDate.day,
      );
      return normalizedDate.isAtSameMomentAs(normalizedBookedDate);
    });
  }

  Future<void> _selectDate({required bool isPickup}) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime utcNow = DateTime.utc(now.year, now.month, now.day);

      // Set the first available date to now for pickup
      DateTime firstAvailableDate = isPickup ? now : (pickupDateTime ?? now);

      // Find the next available date that's not booked
      DateTime initialDate = DateTime(
        firstAvailableDate.year,
        firstAvailableDate.month,
        firstAvailableDate.day,
      );

      // For pickup date, allow same day if it's not booked
      if (isPickup) {
        if (!_isDateBooked(initialDate)) {
          initialDate = firstAvailableDate;
        } else {
          while (_isDateBooked(initialDate)) {
            initialDate = initialDate.add(const Duration(days: 1));
          }
        }
      } else {
        // For return date, allow same day if it's after pickup time
        if (pickupDateTime != null) {
          final pickupDate = DateTime(
            pickupDateTime!.year,
            pickupDateTime!.month,
            pickupDateTime!.day,
          );
          if (!_isDateBooked(initialDate) &&
              initialDate.isAtSameMomentAs(pickupDate)) {
            initialDate = pickupDateTime!;
          } else {
            while (_isDateBooked(initialDate) ||
                initialDate.isBefore(firstAvailableDate)) {
              initialDate = initialDate.add(const Duration(days: 1));
            }
          }
        }
      }

      final DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstAvailableDate,
        lastDate: now.add(const Duration(days: 365)),
        selectableDayPredicate: (DateTime date) {
          // For pickup date, allow same day if it's not booked
          if (isPickup) {
            final normalizedDate = DateTime(date.year, date.month, date.day);
            final normalizedNow = DateTime(now.year, now.month, now.day);
            return !_isDateBooked(date) &&
                !normalizedDate.isBefore(normalizedNow);
          }
          // For return date, allow same day if it's after pickup time
          if (pickupDateTime != null) {
            final pickupDate = DateTime(
              pickupDateTime!.year,
              pickupDateTime!.month,
              pickupDateTime!.day,
            );
            final selectedDate = DateTime(date.year, date.month, date.day);
            return !_isDateBooked(date) &&
                (selectedDate.isAfter(pickupDate) ||
                    selectedDate.isAtSameMomentAs(pickupDate));
          }
          return !_isDateBooked(date) && !date.isBefore(firstAvailableDate);
        },
      );

      if (selectedDate != null && mounted) {
        // Calculate the minimum time based on whether it's today and if it's pickup or return
        TimeOfDay initialTime;
        if (isPickup) {
          // For pickup, if it's today, start from current time
          if (selectedDate.year == now.year &&
              selectedDate.month == now.month &&
              selectedDate.day == now.day) {
            initialTime = TimeOfDay(hour: now.hour, minute: now.minute);
          } else {
            initialTime = TimeOfDay.now();
          }
        } else {
          // For return, if it's same day as pickup, start from pickup time
          if (pickupDateTime != null &&
              selectedDate.year == pickupDateTime!.year &&
              selectedDate.month == pickupDateTime!.month &&
              selectedDate.day == pickupDateTime!.day) {
            initialTime = TimeOfDay(
              hour: pickupDateTime!.hour,
              minute: pickupDateTime!.minute,
            );
          } else {
            initialTime = TimeOfDay.now();
          }
        }

        final TimeOfDay? selectedTime = await showTimePicker(
          context: context,
          initialTime: initialTime,
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
        );

        if (selectedTime != null && mounted) {
          final DateTime combinedDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );

          // Check if the selected time is in the past
          if (isPickup && combinedDateTime.isBefore(now)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot select a time in the past'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // For return date selection, check if the entire range is available
          if (!isPickup && pickupDateTime != null) {
            if (combinedDateTime.isBefore(pickupDateTime!)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Return time must be after pickup time'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Check if the entire date range is available
            final isAvailable = await isDateRangeAvailable(
              pickupDateTime!,
              combinedDateTime,
            );
            if (!isAvailable) {
              return;
            }
          }

          setState(() {
            if (isPickup) {
              pickupDateTime = combinedDateTime;
              // Clear return date if it's before the new pickup date
              if (returnDateTime != null &&
                  returnDateTime!.isBefore(combinedDateTime)) {
                returnDateTime = null;
              }
            } else {
              returnDateTime = combinedDateTime;
            }
          });
        }
      }
    } catch (e) {
      print('Error selecting date/time: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to select date. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int get rentalMinutes {
    if (pickupDateTime == null || returnDateTime == null) return 0;
    return returnDateTime!.difference(pickupDateTime!).inMinutes;
  }

  double get totalCost {
    if (pickupDateTime == null || returnDateTime == null) return 0;

    // Calculate base price per minute (daily price divided by minutes in a day)
    final minutesInDay = 24 * 60; // 1440 minutes
    final pricePerMinute =
        (widget.car.discountedPrice ?? widget.car.price) / minutesInDay;

    // Calculate total cost based on minutes
    double cost = pricePerMinute * rentalMinutes * selectedQuantity;

    // Add extras
    if (addInsurance) cost += 200 * selectedQuantity;
    if (addChildSeat) cost += 100 * selectedQuantity;

    return cost;
  }

  String formatDateTime(DateTime? dt) {
    if (dt == null) return 'Select';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  String formatDuration(int minutes) {
    final days = minutes ~/ (24 * 60);
    final remainingMinutes = minutes % (24 * 60);
    final hours = remainingMinutes ~/ 60;
    final mins = remainingMinutes % 60;

    final parts = <String>[];
    if (days > 0) {
      parts.add('$days day${days > 1 ? 's' : ''}');
    }
    if (hours > 0) {
      parts.add('$hours hour${hours > 1 ? 's' : ''}');
    }
    if (mins > 0 || parts.isEmpty) {
      parts.add('$mins minute${mins > 1 ? 's' : ''}');
    }

    return parts.join(', ');
  }

  void goToPaymentScreen() async {
    if (pickupDateTime == null || returnDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup and return dates.')),
      );
      return;
    }

    if (isCorporateUser && (pickupLocation == null || returnLocation == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup and return locations.'),
        ),
      );
      return;
    }

    if (isCorporateUser) {
      // Check if the number of selected licenses matches the number of vehicles
      final selectedLicenses =
          driverLicenses.where((license) => license['selected'] == true).length;

      if (selectedLicenses != selectedQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select exactly $selectedQuantity driver license(s)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        _showDriverLicenseDialog();
        return;
      }
    }

    // Send notification for booking initiation
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await NotificationService().sendNotification(
        title: 'Booking Initiated',
        body:
            'Your booking for ${widget.car.name} is being processed. Please complete the payment to confirm your reservation.',
        userId: user.uid,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PaymentScreen(
              carId: widget.car.id,
              totalPrice: totalCost,
              startDate: pickupDateTime!,
              endDate: returnDateTime!,
              insurance: addInsurance,
              childSeat: addChildSeat,
              carName: widget.car.name,
              carImage: widget.car.image,
              pickupLocation:
                  isCorporateUser ? pickupLocation! : 'Default Location',
              returnLocation:
                  isCorporateUser ? returnLocation! : 'Default Location',
              quantity: isCorporateUser ? selectedQuantity : 1,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Book ${widget.car.name}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 0),
              ],
            ),
            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
          ),
        ),
      ),
      body: FutureBuilder<Car>(
        future: _getCarDetails(widget.car),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No car details available.'));
          }

          final car = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child:
                        car!.image.startsWith('http')
                            ? Image.network(
                              car!.image,
                              fit: BoxFit.contain,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading image: $error');
                                return const Icon(Icons.image_not_supported);
                              },
                            )
                            : Image.asset(car!.image, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('Pickup Details', theme),
                const SizedBox(height: 16),
                if (isCorporateUser) ...[
                  TextFormField(
                    controller: pickupDateController,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                      hintText: 'YYYY-MM-DD',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _handleDateInput(value, true),
                  ),
                  const SizedBox(height: 16),
                  _buildLocationDropdown(
                    'Pickup Location',
                    pickupLocation,
                    (value) => setState(() => pickupLocation = value),
                    theme,
                  ),
                ] else ...[
                  _buildDateTimeButton(
                    'Pickup Date & Time',
                    formatDateTime(pickupDateTime),
                    () => _selectDate(isPickup: true),
                    theme,
                  ),
                ],

                const SizedBox(height: 24),
                _buildSectionTitle('Return Details', theme),
                const SizedBox(height: 16),
                if (isCorporateUser) ...[
                  TextFormField(
                    controller: returnDateController,
                    decoration: const InputDecoration(
                      labelText: 'Return Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                      hintText: 'YYYY-MM-DD',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _handleDateInput(value, false),
                  ),
                  const SizedBox(height: 16),
                  _buildLocationDropdown(
                    'Return Location',
                    returnLocation,
                    (value) => setState(() => returnLocation = value),
                    theme,
                  ),
                ] else ...[
                  _buildDateTimeButton(
                    'Return Date & Time',
                    formatDateTime(returnDateTime),
                    () => _selectDate(isPickup: false),
                    theme,
                  ),
                ],

                const SizedBox(height: 24),
                _buildSectionTitle('Extras', theme),
                const SizedBox(height: 16),
                _buildCheckboxTile(
                  'Add Insurance',
                  '₺200',
                  addInsurance,
                  (value) => setState(() => addInsurance = value!),
                  theme,
                ),
                _buildCheckboxTile(
                  'Add Child Seat',
                  '₺100',
                  addChildSeat,
                  (value) => setState(() => addChildSeat = value!),
                  theme,
                ),

                const SizedBox(height: 24),
                _buildTotalCost(totalCost, theme),
                const SizedBox(height: 24),

                // Quantity selector
                if (isCorporateUser) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text('Number of Vehicles:'),
                        SizedBox(width: 16),
                        DropdownButton<int>(
                          value: selectedQuantity,
                          items: List.generate(
                            availableStock,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedQuantity = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // Driver license selection
                if (isCorporateUser) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('Driver Licenses', theme),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      print('[BookingScreen] Driver Licenses button pressed.');
                      final updatedLicenses = await _showDriverLicenseDialog();
                      print(
                        '[BookingScreen] Dialog returned: $updatedLicenses',
                      );
                      if (updatedLicenses != null) {
                        setState(() {
                          driverLicenses = updatedLicenses;
                          print(
                            '[BookingScreen] driverLicenses updated. New count: ${driverLicenses.where((license) => license['selected'] == true).length}',
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.drive_file_rename_outline),
                    label: Text(
                      '${driverLicenses.where((license) => license['selected'] == true).length}/$selectedQuantity License(s) Selected',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (driverLicenses
                          .where((license) => license['selected'] == true)
                          .length !=
                      selectedQuantity) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Please select exactly $selectedQuantity driver license(s)',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? theme.cardColor : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: goToPaymentScreen,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Continue to Payment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Future<Car> _getCarDetails(Car car) async {
    return Future.delayed(const Duration(seconds: 2), () => car);
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDateTimeButton(
    String label,
    String value,
    VoidCallback onPressed,
    ThemeData theme,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: isLoading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isDarkMode ? Colors.grey[850] : Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isLoading ? 'Loading...' : value,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.calendar_today, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDropdown(
    String label,
    String? value,
    Function(String?) onChanged,
    ThemeData theme,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isDarkMode ? Colors.grey[850] : Colors.white,
          ),
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              'Select location',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            isExpanded: true,
            underline: Container(),
            dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
            items:
                availableLocations
                    .map(
                      (location) => DropdownMenuItem(
                        value: location,
                        child: Text(
                          location,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxTile(
    String title,
    String price,
    bool value,
    Function(bool?) onChanged,
    ThemeData theme,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? Colors.grey[850] : Colors.white,
      ),
      child: CheckboxListTile(
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            Text(
              price,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildTotalCost(double total, ThemeData theme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDarkMode
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rental Duration',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              Text(
                formatDuration(rentalMinutes),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Cost',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${PriceFormatter.formatPrice(total)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
