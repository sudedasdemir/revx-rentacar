import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/admin/screens/reporting_screen.dart';
import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/services/auth/auth_service.dart';
import 'package:firebase_app/admin/screens/manage_admin_users_list_screen.dart';
import 'package:firebase_app/admin/screens/manage_cars_screen.dart';
import 'package:firebase_app/admin/screens/vehicle_maintenance_screen.dart';
import 'package:firebase_app/admin/screens/questions_management_screen.dart';
import 'package:firebase_app/admin/screens/banner_management_screen.dart';
import 'package:firebase_app/admin/screens/e_bulletin_management_screen.dart';
import 'package:firebase_app/admin/screens/notifications_screen.dart';
import 'package:rxdart/rxdart.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late Stream<QuerySnapshot> _cancellationsStream;
  late Stream<QuerySnapshot> _refundsStream;
  late Stream<QuerySnapshot> _lowStockCarsStream;

  Future<int> _getCollectionCountFuture(String collectionName) async {
    final snapshot =
        await FirebaseFirestore.instance.collection(collectionName).get();
    return snapshot.docs.length;
  }

  Stream<int> _getCollectionCountStream(
    String collectionName, {
    String? status,
  }) {
    Query query = FirebaseFirestore.instance.collection(collectionName);
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _getLowStockCarCountStream() {
    return FirebaseFirestore.instance
        .collection('cars')
        .where('availableQuantity', isLessThan: 5)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  void initState() {
    super.initState();
    _cancellationsStream =
        FirebaseFirestore.instance
            .collection('cancellations')
            .where('status', isEqualTo: 'pending')
            .snapshots();
    _refundsStream =
        FirebaseFirestore.instance
            .collection('refunds')
            .where('status', isEqualTo: 'pending')
            .snapshots();
    _lowStockCarsStream =
        FirebaseFirestore.instance
            .collection('cars')
            .where('availableQuantity', isLessThan: 5)
            .snapshots();
  }

  @override
  void dispose() {
    // ... existing code ...
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home),
            label: const Text('Home'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Logout'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Welcome Admin!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.notifications,
                    color: AppColors.secondary,
                    size: 30,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  tooltip: 'View Notifications',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Logged in as: ${user?.email}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FutureBuilder(
              future: Future.wait([
                _getCollectionCountFuture('users'),
                _getCollectionCountFuture('cars'),
              ]),
              builder: (context, AsyncSnapshot<List<int>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Text('Could not load stats');
                }

                final userCount = snapshot.data![0];
                final carCount = snapshot.data![1];

                return Row(
                  children: [
                    _buildDashboardCard(
                      icon: Icons.people,
                      count: userCount,
                      label: 'Users',
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 16),
                    _buildDashboardCard(
                      icon: Icons.directions_car,
                      count: carCount,
                      label: 'Cars',
                      color: Colors.teal,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _AdminCard(
                    icon: Icons.supervised_user_circle,
                    label: 'Manage Users',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageAdminUsersListScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminCard(
                    icon: Icons.directions_car,
                    label: 'Manage Cars',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageCarsScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminCard(
                    icon: Icons.receipt_long,
                    label: 'Rentals',
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/rentals');
                    },
                  ),
                  _AdminCard(
                    icon: Icons.payment,
                    label: 'Payments',
                    onTap: () {
                      Navigator.pushNamed(context, '/payment_list');
                    },
                  ),
                  _AdminCard(
                    icon: Icons.cancel_outlined,
                    label: 'Cancellations',
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/cancellations');
                    },
                  ),
                  _AdminCard(
                    icon: Icons.business,
                    label: 'Corporate Rentals',
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/corporate-rentals');
                    },
                  ),
                  _AdminCard(
                    icon: Icons.payment,
                    label: 'Corporate Payments',
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/corporate-payments');
                    },
                  ),
                  _AdminCard(
                    icon: Icons.bar_chart,
                    label: 'Reports',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportingScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminCard(
                    icon: Icons.build_circle_outlined,
                    label: 'Vehicle Maintenance',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VehicleMaintenanceScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminCard(
                    icon: Icons.question_answer,
                    label: 'Questions & Answers',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuestionsManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminCard(
                    icon: Icons.image,
                    label: 'Manage Banners',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BannerManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminCard(
                    icon: Icons.announcement,
                    label: 'E-Bulletin',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EBulletinManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminCard(
                    icon: Icons.card_giftcard,
                    label: 'Gift Vouchers',
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/gift-vouchers');
                    },
                  ),
                  _AdminCard(
                    icon: Icons.local_offer,
                    label: 'Discount Management',
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/admin/discount-management',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.secondary),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
