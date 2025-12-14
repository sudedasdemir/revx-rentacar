import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/screens/login_screen.dart';
import 'package:firebase_app/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app/screens/comment_history_screen.dart';
import 'package:firebase_app/screens/notification_screen.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_app/screens/wallet_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  bool isUploading = false;
  File? selectedImage;
  final ImagePicker imagePicker = ImagePicker();
  String? uploadedImageUrl;

  Map<String, dynamic>? userData;
  Map<String, dynamic>? driverLicenseData;
  int totalBookings = 0;
  double totalSpent = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _checkAdminStatus();
    _updateExistingVouchers();
  }

  void _checkAdminStatus() async {
    final isAdmin = await _isUserAdmin();
    print('Initial admin check: $isAdmin');
  }

  Future<void> _loadAllData() async {
    if (user == null) return;
    await _loadUserData();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadUserData() async {
    final userDoc = await firestore.collection('users').doc(user!.uid).get();
    final licenseDoc =
        await firestore.collection('licenseExpiry').doc(user!.uid).get();
    final bookings =
        await firestore
            .collection('bookings')
            .where('userId', isEqualTo: user!.uid)
            .get();

    // Load all payments including voucher deductions
    final payments =
        await firestore
            .collection('payments')
            .where('userId', isEqualTo: user!.uid)
            .get();

    double spent = 0;
    for (var p in payments.docs) {
      final data = p.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final status = data['status'] as String? ?? 'pending';

      // Only count completed payments
      if (status == 'completed') {
        spent += amount;
      }

      // Subtract refunded amounts for cancelled payments
      if (status == 'cancelled' || status == 'refunded') {
        final refundAmount = (data['refundAmount'] as num?)?.toDouble() ?? 0;
        spent -= refundAmount;
      }
    }

    // Load used vouchers to adjust the total spent
    final usedVouchers =
        await firestore
            .collection('gift_vouchers')
            .where('senderId', isEqualTo: user!.uid)
            .where('isUsed', isEqualTo: true)
            .get();

    double usedVoucherAmount = 0;
    for (var voucher in usedVouchers.docs) {
      usedVoucherAmount += (voucher.data()['amount'] ?? 0).toDouble();
    }

    // Load pending and approved vouchers that haven't been used
    final activeVouchers =
        await firestore
            .collection('gift_vouchers')
            .where('senderId', isEqualTo: user!.uid)
            .where('status', isEqualTo: 'approved')
            .where('isUsed', isEqualTo: false)
            .get();

    double activeVoucherAmount = 0;
    for (var voucher in activeVouchers.docs) {
      activeVoucherAmount += (voucher.data()['amount'] ?? 0).toDouble();
    }

    // Adjust total spent by subtracting used voucher amounts
    spent -= usedVoucherAmount;

    // Calculate available discount (1% of total spent minus active vouchers)
    double availableDiscount = (spent * 0.01) - activeVoucherAmount;
    availableDiscount = availableDiscount < 0 ? 0 : availableDiscount;

    // Ensure spent amount is not negative
    spent = spent < 0 ? 0 : spent;

    // Update user document with latest values
    await firestore.collection('users').doc(user!.uid).update({
      'totalSpent': spent,
      'availableDiscount': availableDiscount,
    });

    setState(() {
      userData = userDoc.data();
      driverLicenseData = licenseDoc.data();
      totalBookings = bookings.docs.length;
      totalSpent = spent;
    });
  }

  Future<void> _updateField(String field, dynamic value) async {
    await firestore.collection('users').doc(user!.uid).update({field: value});
    _loadAllData();
  }

  Future<void> _editFieldDialog(
    String field,
    String currentValue, {
    bool isLicense = false,
  }) async {
    if (field == 'issueDate' || field == 'expiryDate') {
      final DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: field == 'issueDate' ? DateTime(1900) : DateTime.now(),
        lastDate:
            field == 'issueDate'
                ? DateTime.now()
                : DateTime.now().add(const Duration(days: 365 * 10)),
      );

      if (selectedDate != null && mounted) {
        try {
          await firestore.collection('licenseExpiry').doc(user!.uid).set({
            field: Timestamp.fromDate(selectedDate),
          }, SetOptions(merge: true));
          await _loadAllData();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error updating date: $e')));
          }
        }
      }
    } else {
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
                  onPressed: () async {
                    Navigator.pop(context);
                    if (isLicense) {
                      await firestore
                          .collection('licenseExpiry')
                          .doc(user!.uid)
                          .set({
                            field: controller.text.trim(),
                          }, SetOptions(merge: true));
                    } else {
                      await _updateField(field, controller.text.trim());
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
      );
    }
  }

  void _toggleSwitch(String field, bool value) async {
    await _updateField(field, value);
  }

  void _changePassword() async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
  }

  void _sendEmailVerification() async {
    if (!user!.emailVerified) {
      await user!.sendEmailVerification();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent.')));
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _createGiftVoucher() async {
    // Calculate available discount (1% of total spent minus active vouchers)
    final activeVouchers =
        await firestore
            .collection('gift_vouchers')
            .where('senderId', isEqualTo: user!.uid)
            .where('status', isEqualTo: 'approved')
            .where('isUsed', isEqualTo: false)
            .get();

    double activeVoucherAmount = 0;
    for (var voucher in activeVouchers.docs) {
      activeVoucherAmount += (voucher.data()['amount'] ?? 0).toDouble();
    }

    final availableAmount = (totalSpent * 0.01) - activeVoucherAmount;
    final amountController = TextEditingController();
    final messageController = TextEditingController();

    if (mounted) {
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Create Gift Voucher'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Available Amount: ${availableAmount.toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (₺)',
                        hintText: 'Enter amount',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'Add a note for yourself',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null ||
                        amount <= 0 ||
                        amount > availableAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      // Create the voucher
                      await firestore.collection('gift_vouchers').add({
                        'senderId': user!.uid,
                        'senderEmail': user!.email,
                        'recipientEmail': user!.email,
                        'amount': amount,
                        'message': messageController.text,
                        'status': 'pending',
                        'createdAt': FieldValue.serverTimestamp(),
                        'type': 'wallet',
                        'isSelfUse': true,
                        'giftCheckAmount': amount,
                        'totalSpent': totalSpent,
                        'isUsed': false,
                      });

                      // Add a payment record for the deduction
                      await firestore.collection('payments').add({
                        'userId': user!.uid,
                        'amount': -amount,
                        'type': 'voucher_creation',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      // Update the user's total spent amount and available discount
                      await firestore
                          .collection('users')
                          .doc(user!.uid)
                          .update({
                            'totalSpent': FieldValue.increment(-amount),
                            'availableDiscount': FieldValue.increment(-amount),
                          });

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gift voucher created successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadAllData(); // Reload all data to reflect changes
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating gift voucher: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            ),
      );
    }
  }

  void _addReview(String review) async {
    await firestore.collection('reviews').add({
      'userId': user!.uid,
      'review': review,
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Review submitted.')));
  }

  Future<bool> _isUserAdmin() async {
    try {
      if (user?.uid == null) return false;

      final adminDoc =
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(user!.uid)
              .get();

      if (adminDoc.exists) {
        print('User ${user!.uid} is an admin');
        return true;
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get();

      final isAdmin = userDoc.data()?['isAdmin'] == true;
      print('User ${user!.uid} admin status: $isAdmin');
      return isAdmin;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  Future<void> _showLicenseInputDialog() async {
    if (mounted) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Important Notice'),
              content: const Text(
                'Users can enter their driver\'s license information only once. Please enter your information correctly.',
                style: TextStyle(color: Colors.red),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('I Understand'),
                ),
              ],
            ),
      );

      if (proceed != true) return;
    }

    final licenseNumberController = TextEditingController();
    DateTime? issueDate;
    DateTime? expiryDate;
    final classController = TextEditingController();

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('Enter Driver\'s License Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: licenseNumberController,
                      decoration: const InputDecoration(
                        labelText: 'License Number',
                        hintText: 'Enter your license number',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        issueDate != null
                            ? 'Issue Date: ${issueDate.toString().split(' ')[0]}'
                            : 'Select Issue Date',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          issueDate = date;
                          (context as Element).markNeedsBuild();
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        expiryDate != null
                            ? 'Expiry Date: ${expiryDate.toString().split(' ')[0]}'
                            : 'Select Expiry Date',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 10),
                          ),
                        );
                        if (date != null) {
                          expiryDate = date;
                          (context as Element).markNeedsBuild();
                        }
                      },
                    ),
                    TextField(
                      controller: classController,
                      decoration: const InputDecoration(
                        labelText: 'License Class',
                        hintText: 'Enter your license class',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (licenseNumberController.text.isEmpty ||
                        issueDate == null ||
                        expiryDate == null ||
                        classController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    try {
                      await firestore
                          .collection('licenseExpiry')
                          .doc(user!.uid)
                          .set({
                            'licenseNumber': licenseNumberController.text,
                            'issueDate': Timestamp.fromDate(issueDate!),
                            'expiryDate': Timestamp.fromDate(expiryDate!),
                            'Class': classController.text,
                          });
                      await _loadAllData();
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving license: $e')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
      );
    }
  }

  Widget _buildTile(String title, String value, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value.isNotEmpty ? value : 'Not set'),
      trailing: const Icon(Icons.edit),
      onTap: onTap,
    );
  }

  Widget _buildStatItem(String title, dynamic value, IconData icon) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Icon(icon, size: 28, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value is double ? '${value.toStringAsFixed(0)}' : value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSettingsTiles(bool isDarkMode) {
    return [
      _buildSettingTile(
        'Notifications',
        'Control your notification preferences',
        Icons.notifications_outlined,
        Switch(
          value: userData?['notificationsEnabled'] ?? true,
          onChanged: (val) => _toggleSwitch('notificationsEnabled', val),
          activeColor: AppColors.primary,
        ),
        isDarkMode,
      ),
      _buildSettingTile(
        'Theme',
        'Switch between light and dark mode',
        Icons.brightness_6_outlined,
        Switch(
          value: isDarkMode,
          onChanged:
              (val) =>
                  Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ).toggleTheme(),
          activeColor: AppColors.primary,
        ),
        isDarkMode,
      ),
    ];
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    IconData icon,
    Widget trailing,
    bool isDarkMode,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildProfileDetailItem(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.edit),
      onTap: onTap,
    );
  }

  Widget _buildLicenseCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (driverLicenseData == null || driverLicenseData!.isEmpty) {
      return Card(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: InkWell(
          onTap: _showLicenseInputDialog,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.drive_eta, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Add Driver\'s License',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to enter your license details',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drive_eta, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Driver\'s License',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildLicenseDetail(
              'License Number',
              driverLicenseData!['licenseNumber'] ?? 'Not set',
            ),
            _buildLicenseDetail(
              'Issue Date',
              _formatDate(driverLicenseData!['issueDate']),
            ),
            _buildLicenseDetail(
              'Expiry Date',
              _formatDate(driverLicenseData!['expiryDate']),
            ),
            _buildLicenseDetail(
              'Class',
              driverLicenseData!['Class'] ?? 'Not set',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not set';
    if (date is Timestamp) {
      return date.toDate().toString().split(' ')[0];
    }
    return date.toString();
  }

  Widget _buildLicenseDetail(String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                ),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final newPassword = passwordController.text.trim();
                  final confirmPassword = confirmController.text.trim();
                  if (newPassword.isEmpty || newPassword != confirmPassword) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match!')),
                    );
                    return;
                  }
                  try {
                    await FirebaseAuth.instance.currentUser!.updatePassword(
                      newPassword,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully!'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Change'),
              ),
            ],
          ),
    );
  }

  Future<void> pickImageFromGallery() async {
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
        isUploading = true;
      });
      await uploadImageToImgur(selectedImage!);
    }
  }

  Future<void> uploadImageToImgur(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {
          'Authorization':
              'Client-ID e97b7b6366d364f', // Replace with your Imgur client ID
        },
        body: {'image': base64Image, 'type': 'base64'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final imageUrl = responseData['data']['link'];

        // Update the user's profile image in Firestore
        await firestore.collection('users').doc(user!.uid).update({
          'profileImage': imageUrl,
        });

        setState(() {
          uploadedImageUrl = imageUrl;
          isUploading = false;
          // Update the local userData state
          userData!['profileImage'] = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully')),
        );
      } else {
        setState(() {
          isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
    }
  }

  Future<void> _updateExistingVouchers() async {
    if (user == null) return;

    try {
      // Get all approved vouchers that haven't been used yet
      final vouchersSnapshot =
          await firestore
              .collection('gift_vouchers')
              .where('senderId', isEqualTo: user!.uid)
              .where('status', isEqualTo: 'approved')
              .where('isUsed', isEqualTo: false)
              .get();

      for (var voucher in vouchersSnapshot.docs) {
        final data = voucher.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final isSelfUse = data['isSelfUse'] ?? false;

        // Check if a payment record already exists for this voucher
        final existingPayment =
            await firestore
                .collection('payments')
                .where('voucherId', isEqualTo: voucher.id)
                .get();

        if (existingPayment.docs.isEmpty) {
          // Create payment record for the voucher
          await firestore.collection('payments').add({
            'userId': user!.uid,
            'amount': -amount,
            'type': 'voucher_usage',
            'voucherId': voucher.id,
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Update user's total spent
          await firestore.collection('users').doc(user!.uid).update({
            'totalSpent': FieldValue.increment(-amount),
          });

          // Mark voucher as used
          await firestore.collection('gift_vouchers').doc(voucher.id).update({
            'isUsed': true,
            'usedAt': FieldValue.serverTimestamp(),
            'usedBy': user!.uid,
            'usedByEmail': user!.email,
          });

          // If it's a self-use voucher, update the available discount
          if (isSelfUse) {
            await firestore.collection('users').doc(user!.uid).update({
              'availableDiscount': FieldValue.increment(-amount),
            });
          }
        }
      }

      // Reload data after updating vouchers
      await _loadAllData();
    } catch (e) {
      print('Error updating existing vouchers: $e');
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(color: Colors.red),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  try {
                    // Delete user data from Firestore collections
                    final batch = firestore.batch();

                    // Delete user document
                    batch.delete(firestore.collection('users').doc(user!.uid));

                    // Delete license expiry document
                    batch.delete(
                      firestore.collection('licenseExpiry').doc(user!.uid),
                    );

                    // Delete user's bookings
                    final bookingsSnapshot =
                        await firestore
                            .collection('bookings')
                            .where('userId', isEqualTo: user!.uid)
                            .get();
                    for (var doc in bookingsSnapshot.docs) {
                      batch.delete(doc.reference);
                    }

                    // Delete user's notifications
                    final notificationsSnapshot =
                        await firestore
                            .collection('notifications')
                            .where('userId', isEqualTo: user!.uid)
                            .get();
                    for (var doc in notificationsSnapshot.docs) {
                      batch.delete(doc.reference);
                    }

                    // Delete user's payments
                    final paymentsSnapshot =
                        await firestore
                            .collection('payments')
                            .where('userId', isEqualTo: user!.uid)
                            .get();
                    for (var doc in paymentsSnapshot.docs) {
                      batch.delete(doc.reference);
                    }

                    // Delete user's reviews
                    final reviewsSnapshot =
                        await firestore
                            .collection('reviews')
                            .where('userId', isEqualTo: user!.uid)
                            .get();
                    for (var doc in reviewsSnapshot.docs) {
                      batch.delete(doc.reference);
                    }

                    // Delete user's gift vouchers
                    final vouchersSnapshot =
                        await firestore
                            .collection('gift_vouchers')
                            .where('senderId', isEqualTo: user!.uid)
                            .get();
                    for (var doc in vouchersSnapshot.docs) {
                      batch.delete(doc.reference);
                    }

                    // Commit all deletions
                    await batch.commit();

                    // Delete the user account from Firebase Auth
                    await user!.delete();

                    if (mounted) {
                      Navigator.pop(context); // Close dialog
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // Close dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting account: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Delete Account'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final isCorporate = (userData?['role'] ?? 'user') == 'corporate';

    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Material(
      color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: pickImageFromGallery,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              userData?['profileImage'] != null
                                  ? NetworkImage(userData!['profileImage'])
                                  : null,
                          backgroundColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          child:
                              userData?['profileImage'] == null
                                  ? Icon(
                                    Icons.person,
                                    size: 50,
                                    color:
                                        isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                  )
                                  : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: GestureDetector(
                        onTap: pickImageFromGallery,
                        child: Icon(
                          isUploading ? Icons.hourglass_empty : Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    if (isUploading)
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  userData?['Name'] ?? '',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  userData?['email'] ?? '',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        'Bookings',
                        totalBookings,
                        Icons.book_online,
                      ),
                      _buildStatItem(
                        'Total Spent',
                        totalSpent,
                        Icons.monetization_on,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Profile Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!isCorporate)
                        _buildProfileDetailItem(
                          'Name',
                          userData?['Name'] ?? 'Not set',
                          Icons.badge,
                          () =>
                              _editFieldDialog('Name', userData?['Name'] ?? ''),
                        ),
                      _buildProfileDetailItem(
                        'Email',
                        userData?['email'] ?? 'Not set',
                        Icons.email,
                        () =>
                            _editFieldDialog('email', userData?['email'] ?? ''),
                      ),
                      _buildProfileDetailItem(
                        'Phone',
                        userData?['phone'] ?? 'Not set',
                        Icons.phone,
                        () =>
                            _editFieldDialog('phone', userData?['phone'] ?? ''),
                      ),
                      _buildProfileDetailItem(
                        'Address',
                        userData?['address'] ?? 'Not set',
                        Icons.location_on,
                        () => _editFieldDialog(
                          'address',
                          userData?['address'] ?? '',
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(Icons.comment, color: AppColors.primary),
                        title: Text(
                          'My Reviews',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text('View and manage your reviews'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const CommentHistoryScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.account_balance_wallet,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          'My Wallet',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Available Discount: ${(totalSpent * 0.01).toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            color:
                                isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WalletScreen(),
                            ),
                          );
                        },
                      ),
                      if (isCorporate) ...[
                        const Divider(),
                        _buildProfileDetailItem(
                          'Company Name',
                          userData?['companyName'] ?? 'Not set',
                          Icons.business,
                          () => _editFieldDialog(
                            'companyName',
                            userData?['companyName'] ?? '',
                          ),
                        ),
                        _buildProfileDetailItem(
                          'Tax ID/VKN',
                          userData?['taxId'] ?? 'Not set',
                          Icons.confirmation_number,
                          () => _editFieldDialog(
                            'taxId',
                            userData?['taxId'] ?? '',
                          ),
                        ),
                        _buildProfileDetailItem(
                          'Authorized Person Full Name',
                          userData?['authorizedPerson'] ?? 'Not set',
                          Icons.person_outline,
                          () => _editFieldDialog(
                            'authorizedPerson',
                            userData?['authorizedPerson'] ?? '',
                          ),
                        ),
                        _buildProfileDetailItem(
                          'Firm Code',
                          userData?['firmCode'] ?? 'Not set',
                          Icons.code,
                          () => _editFieldDialog(
                            'firmCode',
                            userData?['firmCode'] ?? '',
                          ),
                        ),
                        _buildProfileDetailItem(
                          'Company Sector',
                          userData?['companySector'] ?? 'Not set',
                          Icons.apartment,
                          () => _editFieldDialog(
                            'companySector',
                            userData?['companySector'] ?? '',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildLicenseCard(),
                ..._buildSettingsTiles(isDarkMode),
                const SizedBox(height: 32),

                FutureBuilder<bool>(
                  future: _isUserAdmin(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (snapshot.hasData && snapshot.data == true) {
                      print('Showing admin button');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/admin');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text(
                            'Admin Panel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }
                    print('Admin button not shown');
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showDeleteAccountDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete Account'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showChangePasswordDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Change Password'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Sign Out'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.notifications, color: AppColors.primary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
