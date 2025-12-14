import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _driverLicenseData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
      final licenseDoc =
          await FirebaseFirestore.instance
              .collection('licenseExpiry')
              .doc(widget.userId)
              .get();

      setState(() {
        _userData = userDoc.data();
        _driverLicenseData = licenseDoc.data();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateField(
    String collection,
    String docId,
    String field,
    dynamic value,
  ) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(docId).update(
        {field: value},
      );
      _loadUserData(); // Reload data after update
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating $field: $e')));
      }
    }
  }

  Future<void> _editFieldDialog(
    String field,
    String currentValue, {
    bool isLicense = false,
  }) async {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Edit $field'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: 'Enter new $field'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (isLicense) {
                    await _updateField(
                      'licenseExpiry',
                      widget.userId,
                      field,
                      controller.text.trim(),
                    );
                  } else {
                    await _updateField(
                      'users',
                      widget.userId,
                      field,
                      controller.text.trim(),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _editDateFieldDialog(
    String field,
    Timestamp? currentValue,
  ) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: currentValue?.toDate() ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (selectedDate != null && mounted) {
      try {
        await _updateField(
          'licenseExpiry',
          widget.userId,
          field,
          Timestamp.fromDate(selectedDate),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating date: $e')));
        }
      }
    }
  }

  Widget _buildDetailItem(String title, String value, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value.isNotEmpty ? value : 'Not set'),
      trailing: const Icon(Icons.edit),
      onTap: onTap,
    );
  }

  Widget _buildLicenseCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver\'s License',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildDetailItem(
              'License Number',
              _driverLicenseData?['licenseNumber'] ?? 'Not set',
              () => _editFieldDialog(
                'licenseNumber',
                _driverLicenseData?['licenseNumber'] ?? '',
                isLicense: true,
              ),
            ),
            _buildDetailItem(
              'Issue Date',
              _formatDate(_driverLicenseData?['issueDate']),
              () => _editDateFieldDialog(
                'issueDate',
                _driverLicenseData?['issueDate'],
              ),
            ),
            _buildDetailItem(
              'Expiry Date',
              _formatDate(_driverLicenseData?['expiryDate']),
              () => _editDateFieldDialog(
                'expiryDate',
                _driverLicenseData?['expiryDate'],
              ),
            ),
            _buildDetailItem(
              'Class',
              _driverLicenseData?['Class'] ?? 'Not set',
              () => _editFieldDialog(
                'Class',
                _driverLicenseData?['Class'] ?? '',
                isLicense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: AppColors.secondary,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User not found.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailItem(
                  'Email',
                  _userData?['email'] ?? 'N/A',
                  () => _editFieldDialog('email', _userData?['email'] ?? ''),
                ),
                _buildDetailItem(
                  'Role',
                  _userData?['isAdmin'] == true ? 'Admin' : 'User',
                  () => {}, // Role is not directly editable here
                ),
                if (_userData?['createdAt'] != null)
                  _buildDetailItem(
                    'Joined',
                    DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format((_userData!['createdAt'] as Timestamp).toDate()),
                    () => {}, // Joined date is not directly editable
                  ),
                _buildDetailItem(
                  'Name',
                  _userData?['Name'] ?? 'Not set',
                  () => _editFieldDialog('Name', _userData?['Name'] ?? ''),
                ),
                _buildDetailItem(
                  'Phone',
                  _userData?['phone'] ?? 'Not set',
                  () => _editFieldDialog('phone', _userData?['phone'] ?? ''),
                ),
                _buildDetailItem(
                  'Address',
                  _userData?['address'] ?? 'Not set',
                  () =>
                      _editFieldDialog('address', _userData?['address'] ?? ''),
                ),

                if (_userData?['role'] == 'corporate') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    'Corporate Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailItem(
                    'Company Name',
                    _userData?['companyName'] ?? 'Not set',
                    () => _editFieldDialog(
                      'companyName',
                      _userData?['companyName'] ?? '',
                    ),
                  ),
                  _buildDetailItem(
                    'Tax ID/VKN',
                    _userData?['taxId'] ?? 'Not set',
                    () => _editFieldDialog('taxId', _userData?['taxId'] ?? ''),
                  ),
                  _buildDetailItem(
                    'Authorized Person Full Name',
                    _userData?['authorizedPerson'] ?? 'Not set',
                    () => _editFieldDialog(
                      'authorizedPerson',
                      _userData?['authorizedPerson'] ?? '',
                    ),
                  ),
                  _buildDetailItem(
                    'Firm Code',
                    _userData?['firmCode'] ?? 'Not set',
                    () => _editFieldDialog(
                      'firmCode',
                      _userData?['firmCode'] ?? '',
                    ),
                  ),
                  _buildDetailItem(
                    'Company Sector',
                    _userData?['companySector'] ?? 'Not set',
                    () => _editFieldDialog(
                      'companySector',
                      _userData?['companySector'] ?? '',
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                _buildLicenseCard(),

                const SizedBox(height: 16),
                const Divider(),
                // Action buttons (delete / block)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _deleteUser(context),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          () => _toggleBlockUser(
                            context,
                            _userData?['isBlocked'] ?? false,
                          ),
                      icon: Icon(
                        _userData?['isBlocked'] == true
                            ? Icons.check_circle
                            : Icons.block,
                      ),
                      label: Text(
                        _userData?['isBlocked'] == true ? 'Unblock' : 'Block',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // DATE FORMATTER
  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }

  // DELETE USER
  void _deleteUser(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete User'),
            content: const Text('Are you sure you want to delete this user?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .delete();
      Navigator.pop(context);
    }
  }

  // TOGGLE BLOCK USER
  void _toggleBlockUser(BuildContext context, bool isBlocked) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);

    await userRef.update({'isBlocked': !isBlocked});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isBlocked ? 'User unblocked.' : 'User blocked.')),
    );
    _loadUserData(); // Reload data to update the button label
  }
}
