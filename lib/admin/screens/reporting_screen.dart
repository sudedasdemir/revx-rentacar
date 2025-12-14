import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:intl/intl.dart';

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({Key? key}) : super(key: key);

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  String selectedPeriod = 'daily';
  double totalIncome = 0;
  double totalExpenses = 0;
  double maintenanceExpenses = 0;
  double giftVoucherExpenses = 0;
  double netProfit = 0;
  double totalRefunds = 0;
  double totalCancellationFees = 0;
  int totalRentals = 0;
  int totalCancellations = 0;
  int totalUsers = 0;
  int activeUsers = 0;
  List<BarChartGroupData> barChartData = [];
  List<Map<String, dynamic>> mostRentedCars = [];
  List<Map<String, dynamic>> recentCancellations = [];
  List<Map<String, dynamic>> maintenanceRecords = [];
  List<Map<String, dynamic>> giftVoucherRecords = [];
  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;

  Future<void> fetchReportData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final dates = _getDateRange();
      startDate = dates['start'];
      endDate = dates['end'];

      final bookingsRef = FirebaseFirestore.instance.collection('bookings');
      final carsRef = FirebaseFirestore.instance.collection('cars');
      final usersRef = FirebaseFirestore.instance.collection('users');
      final maintenanceRef = FirebaseFirestore.instance.collection(
        'maintenance',
      );
      final giftVouchersRef = FirebaseFirestore.instance.collection(
        'giftVouchers',
      );

      // Get all cars first for reference
      final carsSnapshot = await carsRef.get();
      final Map<String, String> carNames = {};
      for (var doc in carsSnapshot.docs) {
        carNames[doc.id] = '${doc.data()['brand']} ${doc.data()['name']}';
      }

      // Get user statistics for the selected period
      final usersSnapshot =
          await usersRef
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!),
              )
              .where(
                'createdAt',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate!),
              )
              .get();

      // Calculate user statistics based on the selected period
      totalUsers = usersSnapshot.docs.length;

      // Get all users for active/deleted calculation
      final allUsersSnapshot = await usersRef.get();
      final allUsers = allUsersSnapshot.docs;

      // Calculate active and deleted users for the period
      activeUsers =
          allUsers.where((doc) {
            final userData = doc.data();
            final createdAt = userData['createdAt'] as Timestamp?;
            final isDeleted = userData['isDeleted'] ?? false;
            final deletedAt = userData['deletedAt'] as Timestamp?;

            // Check if user was active during the period
            if (createdAt == null) return false;

            final userCreatedDate = createdAt.toDate();
            if (userCreatedDate.isAfter(endDate!)) return false;

            // If user was deleted, check if deletion happened after the period
            if (isDeleted && deletedAt != null) {
              final userDeletedDate = deletedAt.toDate();
              return userDeletedDate.isAfter(startDate!);
            }

            return true;
          }).length;

      // Get bookings for the selected period
      final bookingsSnapshot =
          await bookingsRef
              .where(
                'startDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!),
              )
              .where(
                'startDate',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate!),
              )
              .get();

      // Get maintenance records for the selected period
      final maintenanceSnapshot =
          await maintenanceRef
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!),
              )
              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!))
              .get();

      // Get gift voucher records for the selected period
      final giftVouchersSnapshot =
          await giftVouchersRef
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!),
              )
              .where(
                'createdAt',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate!),
              )
              .get();

      // Reset expense counters
      maintenanceExpenses = 0;
      giftVoucherExpenses = 0;
      totalExpenses = 0;
      maintenanceRecords.clear();
      giftVoucherRecords.clear();

      // Calculate maintenance expenses from main maintenance collection
      for (var doc in maintenanceSnapshot.docs) {
        final data = doc.data();
        final cost = data['cost'] as num?;
        final maintenanceDate = data['date'] as Timestamp?;
        final description = data['description'] as String?;
        final carId = data['carId'] as String?;

        if (maintenanceDate != null &&
            maintenanceDate.toDate().isAfter(startDate!) &&
            maintenanceDate.toDate().isBefore(endDate!)) {
          if (cost != null) {
            maintenanceExpenses += cost.toDouble();
            totalExpenses += cost.toDouble();

            // Get car details
            String carName = 'Unknown Car';
            if (carId != null) {
              carName = carNames[carId] ?? 'Unknown Car';
            }

            maintenanceRecords.add({
              'date': maintenanceDate.toDate(),
              'cost': cost.toDouble(),
              'description': description ?? 'No description',
              'carName': carName,
            });
          }
        }
      }

      // Calculate maintenance expenses from car subcollections
      for (var carDoc in carsSnapshot.docs) {
        final carId = carDoc.id;
        final carName = carNames[carId] ?? 'Unknown Car';

        // Get maintenance records for this car
        final carMaintenanceSnapshot =
            await carsRef
                .doc(carId)
                .collection('maintenances')
                .where(
                  'date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!),
                )
                .where(
                  'date',
                  isLessThanOrEqualTo: Timestamp.fromDate(endDate!),
                )
                .get();

        // Calculate maintenance expenses for this car
        for (var maintenanceDoc in carMaintenanceSnapshot.docs) {
          final maintenanceData = maintenanceDoc.data();
          final cost = maintenanceData['cost'] as num?;
          final date = maintenanceData['date'] as Timestamp?;
          final description = maintenanceData['description'] as String?;
          final status = maintenanceData['status'] as String?;

          if (cost != null && date != null && status == 'completed') {
            maintenanceExpenses += cost.toDouble();
            totalExpenses += cost.toDouble();

            maintenanceRecords.add({
              'date': date.toDate(),
              'cost': cost.toDouble(),
              'description': description ?? 'No description',
              'carName': carName,
            });
          }
        }
      }

      // Sort maintenance records by date
      maintenanceRecords.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      // Calculate gift voucher expenses
      for (var doc in giftVouchersSnapshot.docs) {
        final data = doc.data();
        final amount = data['amount'] as num?;
        final createdAt = data['createdAt'] as Timestamp?;
        final status = data['status'] as String?;
        final recipientEmail = data['recipientEmail'] as String?;

        if (createdAt != null &&
            createdAt.toDate().isAfter(startDate!) &&
            createdAt.toDate().isBefore(endDate!)) {
          if (amount != null && status == 'active') {
            giftVoucherExpenses += amount.toDouble();
            totalExpenses += amount.toDouble();

            giftVoucherRecords.add({
              'date': createdAt.toDate(),
              'amount': amount.toDouble(),
              'recipientEmail': recipientEmail ?? 'Unknown',
              'status': status,
            });
          }
        }
      }

      // Process bookings and calculate statistics
      final Map<String, int> carRentals = {};
      totalRentals = 0;
      totalIncome = 0;
      totalRefunds = 0;
      totalCancellationFees = 0;
      recentCancellations.clear();

      // Calculate income and cancellations from bookings
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final carId = data['carId'] as String?;
        final amount = data['totalAmount'] as num?;
        final status = data['status'] as String?;
        final bookingDate = data['startDate'] as Timestamp?;

        // Only process bookings within the selected period
        if (bookingDate != null &&
            bookingDate.toDate().isAfter(startDate!) &&
            bookingDate.toDate().isBefore(endDate!)) {
          if (carId != null) {
            carRentals[carId] = (carRentals[carId] ?? 0) + 1;
            totalRentals++;
          }

          if (amount != null) {
            totalIncome += amount.toDouble();
          }

          // Process cancellations
          if (status == 'cancelled') {
            totalCancellations++;

            // Get cancellation details
            final cancellationData =
                data['cancellation'] as Map<String, dynamic>?;
            final refundAmount = data['refundAmount'] as num?;
            final cancellationFee = data['cancellationFee'] as num?;
            final cancellationDate = data['cancellationDate'] as Timestamp?;

            // Calculate refund amount (if not specified, use 80% of the booking amount)
            final actualRefundAmount =
                refundAmount?.toDouble() ??
                (amount != null ? amount.toDouble() * 0.8 : 0);
            totalRefunds += actualRefundAmount;

            // Calculate cancellation fee (if not specified, use 20% of the booking amount)
            final actualCancellationFee =
                cancellationFee?.toDouble() ??
                (amount != null ? amount.toDouble() * 0.2 : 0);
            totalCancellationFees += actualCancellationFee;

            // Add to recent cancellations list if within period
            if (cancellationDate != null &&
                cancellationDate.toDate().isAfter(startDate!) &&
                cancellationDate.toDate().isBefore(endDate!)) {
              recentCancellations.add({
                'carName': carNames[carId] ?? 'Unknown Car',
                'amount': amount?.toDouble() ?? 0,
                'refundAmount': actualRefundAmount,
                'cancellationFee': actualCancellationFee,
                'date': cancellationDate.toDate(),
              });
            }
          }
        }
      }

      // Calculate net profit (including cancellation fees)
      netProfit =
          totalIncome - totalExpenses + totalCancellationFees - totalRefunds;

      // Sort recent cancellations by date
      recentCancellations.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      // Prepare most rented cars data
      mostRentedCars =
          carRentals.entries.map((entry) {
              return {
                'id': entry.key,
                'carName': carNames[entry.key] ?? 'Unknown Car',
                'rentCount': entry.value,
              };
            }).toList()
            ..sort(
              (a, b) =>
                  (b['rentCount'] as int).compareTo(a['rentCount'] as int),
            );

      // Prepare chart data
      barChartData = [
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: totalIncome,
              color: Colors.green,
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
            BarChartRodData(
              toY: totalExpenses,
              color: Colors.red,
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
            BarChartRodData(
              toY: netProfit,
              color: Colors.blue,
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
          ],
        ),
      ];

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching report data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, DateTime> _getDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (selectedPeriod) {
      case 'annual':
        start = DateTime(now.year - 1, now.month, now.day, 0, 0, 0);
        break;
      case 'weekly':
        start = DateTime(now.year, now.month, now.day - 7, 0, 0, 0);
        break;
      case 'monthly':
        start = DateTime(now.year, now.month - 1, now.day, 0, 0, 0);
        break;
      default: // daily
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
    }

    return {'start': start, 'end': end};
  }

  String _getPeriodDisplay() {
    if (startDate == null || endDate == null)
      return selectedPeriod.toUpperCase();

    final dateFormat = DateFormat('MMM d, yyyy');
    switch (selectedPeriod) {
      case 'annual':
        return '${dateFormat.format(startDate!)} - ${dateFormat.format(endDate!)}';
      case 'weekly':
        return '${dateFormat.format(startDate!)} - ${dateFormat.format(endDate!)}';
      case 'monthly':
        return DateFormat('MMMM yyyy').format(startDate!);
      default: // daily
        return dateFormat.format(startDate!);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchReportData();
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Animate(
      effects: [
        FadeEffect(duration: 500.ms),
        ScaleEffect(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0)),
      ],
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reporting & Statistics"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchReportData,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: fetchReportData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period Selector
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: selectedPeriod,
                                items:
                                    ['daily', 'weekly', 'monthly', 'annual']
                                        .map(
                                          (period) => DropdownMenuItem(
                                            value: period,
                                            child: Text(period.toUpperCase()),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedPeriod = value;
                                      fetchReportData();
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Select Period",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getPeriodDisplay(),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // User Statistics
                      Text(
                        "User Statistics",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              "Total Users",
                              totalUsers.toString(),
                              Icons.people,
                              Colors.purple,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              "Active Users",
                              activeUsers.toString(),
                              Icons.person,
                              Colors.blue,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Profit & Loss Statistics
                      Text(
                        "Profit & Loss",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              "Total Income",
                              "${PriceFormatter.formatPrice(totalIncome)}",
                              Icons.arrow_upward,
                              Colors.green,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              "Total Expenses",
                              "${PriceFormatter.formatPrice(totalExpenses)}",
                              Icons.arrow_downward,
                              Colors.red,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              "Net Profit",
                              "${PriceFormatter.formatPrice(netProfit)}",
                              Icons.account_balance,
                              netProfit >= 0 ? Colors.blue : Colors.red,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Rental Statistics
                      Text(
                        "Rental Statistics",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceEvenly,
                        children: [
                          _buildSummaryCard(
                            "Total Rentals",
                            totalRentals.toString(),
                            Icons.directions_car,
                            Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Cancellation Statistics
                      Text(
                        "Cancellation Statistics",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              "Total Cancellations",
                              totalCancellations.toString(),
                              Icons.cancel,
                              Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              "Total Refunds",
                              "${PriceFormatter.formatPrice(totalRefunds)}",
                              Icons.money_off,
                              Colors.red,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              "Cancellation Fees",
                              "${PriceFormatter.formatPrice(totalCancellationFees)}",
                              Icons.attach_money,
                              Colors.green,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Expense Breakdown Section
                      Text(
                        "Expense Breakdown",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              "Maintenance Expenses",
                              PriceFormatter.formatPrice(maintenanceExpenses),
                              Icons.build,
                              Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              "Gift Voucher Expenses",
                              PriceFormatter.formatPrice(giftVoucherExpenses),
                              Icons.card_giftcard,
                              Colors.purple,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              "Total Expenses",
                              PriceFormatter.formatPrice(totalExpenses),
                              Icons.money_off,
                              Colors.red,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Maintenance Records
                      if (maintenanceRecords.isNotEmpty) ...[
                        Text(
                          "Maintenance Records",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: maintenanceRecords.length,
                            separatorBuilder:
                                (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final record = maintenanceRecords[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.build,
                                  color: Colors.orange,
                                ),
                                title: Text(record['carName']),
                                subtitle: Text(
                                  '${record['description']}\n'
                                  '${DateFormat('MMM d, yyyy').format(record['date'])}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  PriceFormatter.formatPrice(record['cost']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Gift Voucher Records
                      if (giftVoucherRecords.isNotEmpty) ...[
                        Text(
                          "Gift Voucher Records",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: giftVoucherRecords.length,
                            separatorBuilder:
                                (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final record = giftVoucherRecords[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.card_giftcard,
                                  color: Colors.purple,
                                ),
                                title: Text(record['recipientEmail']),
                                subtitle: Text(
                                  '${DateFormat('MMM d, yyyy').format(record['date'])}\n'
                                  'Status: ${record['status']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  PriceFormatter.formatPrice(record['amount']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Bar Chart
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Financial Overview",
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child:
                                    barChartData.isEmpty
                                        ? const Center(
                                          child: Text(
                                            "No data available for selected period.",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        )
                                        : BarChart(
                                          BarChartData(
                                            alignment:
                                                BarChartAlignment.spaceAround,
                                            maxY:
                                                max(
                                                  max(
                                                    totalIncome,
                                                    totalExpenses,
                                                  ),
                                                  netProfit.abs(),
                                                ) *
                                                1.2,
                                            titlesData: FlTitlesData(
                                              show: true,
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget: (
                                                    value,
                                                    meta,
                                                  ) {
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 8.0,
                                                          ),
                                                      child: Text(
                                                        value == 0
                                                            ? selectedPeriod
                                                                .toUpperCase()
                                                            : '',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 40,
                                                ),
                                              ),
                                              rightTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                              topTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                            ),
                                            borderData: FlBorderData(
                                              show: false,
                                            ),
                                            barGroups: barChartData,
                                            gridData: FlGridData(show: true),
                                          ),
                                        ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 24,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildLegendItem('Income', Colors.green),
                                  _buildLegendItem('Expenses', Colors.red),
                                  _buildLegendItem('Net Profit', Colors.blue),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Most Rented Cars
                      if (mostRentedCars.isNotEmpty) ...[
                        Text(
                          "Most Rented Cars",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: mostRentedCars.length,
                            separatorBuilder:
                                (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final car = mostRentedCars[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.directions_car,
                                  color: Colors.blue,
                                ),
                                title: Text(
                                  car['carName'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  '${car['rentCount']} rentals',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Recent Cancellations
                      if (recentCancellations.isNotEmpty) ...[
                        Text(
                          "Recent Cancellations",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentCancellations.length,
                            separatorBuilder:
                                (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final cancellation = recentCancellations[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.cancel,
                                  color: Colors.orange,
                                ),
                                title: Text(
                                  cancellation['carName'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'Original: ${PriceFormatter.formatPrice(cancellation['amount'])}\n'
                                  'Refund: ${PriceFormatter.formatPrice(cancellation['refundAmount'])}\n'
                                  'Fee: ${PriceFormatter.formatPrice(cancellation['cancellationFee'])}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  '${cancellation['date'].toString().split(' ')[0]}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }
}
