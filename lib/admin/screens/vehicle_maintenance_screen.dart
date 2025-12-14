import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/admin/screens/manage_cars_screen.dart';

class VehicleMaintenanceScreen extends StatelessWidget {
  final String? carId;

  const VehicleMaintenanceScreen({super.key, this.carId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          carId == null ? 'Vehicles in Maintenance' : 'Vehicle Maintenance',
        ),
        backgroundColor: Colors.red,
      ),
      body:
          carId == null
              ? _buildMaintenanceList()
              : _buildSingleVehicleMaintenance(context, carId!),
    );
  }

  Widget _buildMaintenanceList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('cars')
              .where('isInMaintenance', isEqualTo: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No vehicles currently in maintenance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Go to Manage Cars to take vehicles to maintenance',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageCarsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions_car),
                  label: const Text('Go to Manage Cars'),
                ),
              ],
            ),
          );
        }

        final vehicles = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index].data() as Map<String, dynamic>;
            final vehicleId = vehicles[index].id;
            final vehicleName = '${vehicle['brand']} ${vehicle['name']}';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: SizedBox(
                      width: 60,
                      height: 60,
                      child:
                          vehicle['image'] != null
                              ? Image.network(
                                vehicle['image'],
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading image: $error');
                                  print('Image URL: ${vehicle['image']}');
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 24,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Image Error',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                              : const Icon(Icons.directions_car, size: 40),
                    ),
                    title: Text(
                      vehicleName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category: ${vehicle['category'] ?? 'N/A'}\nFuel: ${vehicle['fuelType'] ?? '-'} | Transmission: ${vehicle['transmission'] ?? '-'}',
                        ),
                        const SizedBox(height: 4),
                        if (vehicle['maintenanceStartDate'] != null &&
                            vehicle['maintenanceEndDate'] != null)
                          Text(
                            'Maintenance: '
                            '${(vehicle['maintenanceStartDate'] as Timestamp).toDate().toString().split(' ')[0]}'
                            ' → '
                            '${(vehicle['maintenanceEndDate'] as Timestamp).toDate().toString().split(' ')[0]}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _markAsAvailable(context, vehicleId),
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('cars')
                            .doc(vehicleId)
                            .collection('maintenances')
                            .orderBy('date', descending: true)
                            .limit(1)
                            .snapshots(),
                    builder: (context, maintenanceSnapshot) {
                      if (!maintenanceSnapshot.hasData ||
                          maintenanceSnapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final maintenance =
                          maintenanceSnapshot.data!.docs.first.data()
                              as Map<String, dynamic>;
                      final date = (maintenance['date'] as Timestamp).toDate();
                      final description = maintenance['description'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              'Latest Maintenance:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${date.toLocal().toString().split('.')[0]}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed:
                              () => addMaintenanceDialog(context, vehicleId),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Maintenance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              () => _viewMaintenanceHistory(
                                context,
                                vehicleId,
                                vehicleName,
                              ),
                          icon: const Icon(Icons.history),
                          label: const Text('View History'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
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
  }

  Widget _buildSingleVehicleMaintenance(
    BuildContext context,
    String vehicleId,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('cars')
              .doc(vehicleId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Vehicle not found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: $vehicleId',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        final vehicle = snapshot.data!.data() as Map<String, dynamic>;
        final vehicleName = '${vehicle['brand']} ${vehicle['name']}';
        final isInMaintenance = vehicle['isInMaintenance'] ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (vehicle['image'] != null)
                            Image.network(
                              vehicle['image'],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading image: $error');
                                print('Image URL: ${vehicle['image']}');
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[200],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 24,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Image Error',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            const Icon(Icons.directions_car, size: 80),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicleName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isInMaintenance
                                            ? Colors.red.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isInMaintenance
                                            ? Icons.build
                                            : Icons.check_circle,
                                        color:
                                            isInMaintenance
                                                ? Colors.red
                                                : Colors.green,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isInMaintenance
                                            ? 'In Maintenance'
                                            : 'Available',
                                        style: TextStyle(
                                          color:
                                              isInMaintenance
                                                  ? Colors.red
                                                  : Colors.green,
                                          fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed:
                            () => _toggleMaintenanceStatus(
                              context,
                              vehicleId,
                              !isInMaintenance,
                            ),
                        icon: Icon(
                          isInMaintenance ? Icons.check_circle : Icons.build,
                          color: Colors.white,
                        ),
                        label: Text(
                          isInMaintenance
                              ? 'Mark as Available'
                              : 'Take to Maintenance',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isInMaintenance ? Colors.green : Colors.red,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Maintenance History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('cars')
                        .doc(vehicleId)
                        .collection('maintenances')
                        .orderBy('date', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No maintenance records found'),
                    );
                  }

                  final maintenanceDocs = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: maintenanceDocs.length,
                    itemBuilder: (context, index) {
                      final maintenanceData =
                          maintenanceDocs[index].data() as Map<String, dynamic>;
                      final description = maintenanceData['description'];
                      final cost = maintenanceData['cost'];
                      final status = maintenanceData['status'];
                      final technician = maintenanceData['technician'];
                      final date =
                          (maintenanceData['date'] as Timestamp).toDate();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    status == 'completed'
                                        ? Icons.check_circle
                                        : status == 'in_progress'
                                        ? Icons.build
                                        : Icons.schedule,
                                    color:
                                        status == 'completed'
                                            ? Colors.green
                                            : status == 'in_progress'
                                            ? Colors.orange
                                            : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          status == 'completed'
                                              ? Colors.green
                                              : status == 'in_progress'
                                              ? Colors.orange
                                              : Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    date.toLocal().toString().split('.')[0],
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (technician != null) ...[
                                    const Icon(Icons.person, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Technician: $technician',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    'Cost: ₺$cost',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => addMaintenanceDialog(context, vehicleId),
                icon: const Icon(Icons.add),
                label: const Text('Add New Maintenance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleMaintenanceStatus(
    BuildContext context,
    String vehicleId,
    bool setInMaintenance,
  ) async {
    try {
      if (setInMaintenance) {
        // Show dialog to get maintenance start and end dates
        final DateTime? startDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'Select Maintenance Start Date',
        );

        if (startDate == null) {
          return; // User cancelled
        }

        final DateTime? endDate = await showDatePicker(
          context: context,
          initialDate: startDate.add(const Duration(days: 1)),
          firstDate: startDate,
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'Select Maintenance End Date',
        );

        if (endDate == null) {
          return; // User cancelled
        }

        if (endDate.isBefore(startDate)) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End date must be after start date'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final carRef = FirebaseFirestore.instance
            .collection('cars')
            .doc(vehicleId);

        // Start a transaction to ensure data consistency
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final carDoc = await transaction.get(carRef);

          if (!carDoc.exists) {
            throw Exception('Car not found');
          }

          // Check if there are any active bookings
          final bookingsSnapshot =
              await FirebaseFirestore.instance
                  .collection('bookings')
                  .where('carId', isEqualTo: vehicleId)
                  .where('status', whereIn: ['active', 'ongoing', 'pending'])
                  .get();

          if (bookingsSnapshot.docs.isNotEmpty) {
            throw Exception(
              'Cannot take car to maintenance: Active bookings exist',
            );
          }

          // Update car maintenance status with start and end dates
          transaction.update(carRef, {
            'isInMaintenance': true,
            'maintenanceStartDate': Timestamp.fromDate(startDate),
            'maintenanceEndDate': Timestamp.fromDate(endDate),
            'lastMaintenanceUpdate': FieldValue.serverTimestamp(),
          });

          // Add a maintenance record
          final maintenanceRef = carRef.collection('maintenances').doc();
          transaction.set(maintenanceRef, {
            'date': Timestamp.fromDate(startDate),
            'endDate': Timestamp.fromDate(endDate),
            'description': 'Vehicle taken to maintenance',
            'status': 'in_progress',
            'cost': 0, // Initial cost
            'technician': 'System', // Default technician
          });
        });

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vehicle taken to maintenance from ${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Marking as available
        await FirebaseFirestore.instance
            .collection('cars')
            .doc(vehicleId)
            .update({
              'isInMaintenance': false,
              'maintenanceStartDate': FieldValue.delete(),
              'maintenanceEndDate': FieldValue.delete(),
              'lastMaintenanceUpdate': FieldValue.serverTimestamp(),
            });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle marked as available'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // If we're marking as available, pop back to the maintenance list
      if (!setInMaintenance && context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method to check and update maintenance status
  static Future<void> checkMaintenanceStatus() async {
    final now = DateTime.now();
    final carsRef = FirebaseFirestore.instance.collection('cars');

    // Get all cars in maintenance
    final carsInMaintenance =
        await carsRef.where('isInMaintenance', isEqualTo: true).get();

    for (var car in carsInMaintenance.docs) {
      final maintenanceEndDate = car.data()['maintenanceEndDate'] as Timestamp?;
      final maintenanceStartDate =
          car.data()['maintenanceStartDate'] as Timestamp?;

      if (maintenanceStartDate != null && maintenanceEndDate != null) {
        final startDate = maintenanceStartDate.toDate();
        final endDate = maintenanceEndDate.toDate();

        // If current time is before start date, car should be available
        if (now.isBefore(startDate)) {
          await carsRef.doc(car.id).update({
            'isInMaintenance': false,
            'lastMaintenanceUpdate': FieldValue.serverTimestamp(),
          });
        }
        // If current time is after start date and before end date, car should be in maintenance
        else if (now.isAfter(startDate) && now.isBefore(endDate)) {
          await carsRef.doc(car.id).update({
            'isInMaintenance': true,
            'lastMaintenanceUpdate': FieldValue.serverTimestamp(),
          });
        }
        // If current time is after end date, car should be available
        else if (now.isAfter(endDate)) {
          await carsRef.doc(car.id).update({
            'isInMaintenance': false,
            'maintenanceStartDate': FieldValue.delete(),
            'maintenanceEndDate': FieldValue.delete(),
            'lastMaintenanceUpdate': FieldValue.serverTimestamp(),
          });

          // Add a completed maintenance record
          await carsRef.doc(car.id).collection('maintenances').add({
            'date': FieldValue.serverTimestamp(),
            'description': 'Maintenance completed automatically',
            'status': 'completed',
            'cost': 0,
            'technician': 'System',
          });
        }
      }
    }
  }

  Future<void> _markAsAvailable(BuildContext context, String vehicleId) async {
    try {
      await FirebaseFirestore.instance
          .collection('cars')
          .doc(vehicleId)
          .update({
            'isInMaintenance': false,
            'lastMaintenanceUpdate': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle marked as available'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewMaintenanceHistory(
    BuildContext context,
    String vehicleId,
    String vehicleName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => MaintenanceHistoryScreen(
              vehicleId: vehicleId,
              vehicleName: vehicleName,
            ),
      ),
    );
  }

  Future<void> addMaintenanceDialog(BuildContext context, String carId) {
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    final technicianController = TextEditingController();
    String status = 'in_progress';
    DateTime? startDate;
    DateTime? endDate;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Maintenance Record'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'What maintenance is being performed?',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cost (₺)',
                        hintText: 'Enter maintenance cost',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: technicianController,
                      decoration: const InputDecoration(
                        labelText: 'Technician',
                        hintText: 'Who is performing the maintenance?',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                        DropdownMenuItem(
                          value: 'scheduled',
                          child: Text('Scheduled'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            status = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Maintenance Start Date'),
                      subtitle: Text(
                        startDate == null
                            ? 'Select start date'
                            : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            startDate = picked;
                            // If endDate is before new startDate, reset endDate
                            if (endDate != null && endDate!.isBefore(picked)) {
                              endDate = null;
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Maintenance End Date'),
                      subtitle: Text(
                        endDate == null
                            ? 'Select end date'
                            : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate:
                              endDate ??
                              (startDate ?? DateTime.now()).add(
                                const Duration(days: 1),
                              ),
                          firstDate: startDate ?? DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            endDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final description = descriptionController.text.trim();
                    final cost =
                        double.tryParse(costController.text.trim()) ?? 0.0;
                    final technician = technicianController.text.trim();

                    if (description.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a description'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (startDate == null || endDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select both start and end dates',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (endDate!.isBefore(startDate!)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('End date must be after start date'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final maintenanceRef = FirebaseFirestore.instance
                        .collection('cars')
                        .doc(carId)
                        .collection('maintenances');

                    await maintenanceRef.add({
                      'description': description,
                      'cost': cost,
                      'status': status,
                      'technician': technician,
                      'date': Timestamp.fromDate(startDate!),
                      'endDate': Timestamp.fromDate(endDate!),
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Maintenance record added successfully',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class MaintenanceHistoryScreen extends StatelessWidget {
  final String vehicleId;
  final String vehicleName;

  const MaintenanceHistoryScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Maintenance History - $vehicleName')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('cars')
                .doc(vehicleId)
                .collection('maintenances')
                .orderBy('date', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No maintenance records found'));
          }

          final maintenanceDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: maintenanceDocs.length,
            itemBuilder: (context, index) {
              final maintenanceData =
                  maintenanceDocs[index].data() as Map<String, dynamic>;
              final description = maintenanceData['description'];
              final cost = maintenanceData['cost'];
              final status = maintenanceData['status'];
              final technician = maintenanceData['technician'];
              final date = (maintenanceData['date'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            status == 'completed'
                                ? Icons.check_circle
                                : status == 'in_progress'
                                ? Icons.build
                                : Icons.schedule,
                            color:
                                status == 'completed'
                                    ? Colors.green
                                    : status == 'in_progress'
                                    ? Colors.orange
                                    : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color:
                                  status == 'completed'
                                      ? Colors.green
                                      : status == 'in_progress'
                                      ? Colors.orange
                                      : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            date.toLocal().toString().split('.')[0],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (technician != null) ...[
                            const Icon(Icons.person, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Technician: $technician',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const Spacer(),
                          Text(
                            'Cost: ₺$cost',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
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
