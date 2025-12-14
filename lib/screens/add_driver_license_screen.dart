import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/colors.dart';
import 'package:intl/intl.dart';

class AddDriverLicenseScreen extends StatefulWidget {
  const AddDriverLicenseScreen({super.key});

  @override
  State<AddDriverLicenseScreen> createState() => _AddDriverLicenseScreenState();
}

class _AddDriverLicenseScreenState extends State<AddDriverLicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isIssueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
          // Set expiry date to 10 years from issue date if not set
          if (_expiryDate == null) {
            _expiryDate = DateTime(picked.year + 10, picked.month, picked.day);
          }
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _saveLicense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_issueDate == null || _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both issue and expiry dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      await FirebaseFirestore.instance.collection('driver_licenses').add({
        'userId': user.uid,
        'name': _nameController.text,
        'licenseNumber': _licenseNumberController.text,
        'issueDate': Timestamp.fromDate(_issueDate!),
        'expiryDate': Timestamp.fromDate(_expiryDate!),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver license added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding license: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Driver License'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _licenseNumberController,
                decoration: const InputDecoration(
                  labelText: 'License Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your license number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Issue Date'),
                subtitle: Text(
                  _issueDate == null
                      ? 'Select issue date'
                      : DateFormat('MMM dd, yyyy').format(_issueDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(true),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Expiry Date'),
                subtitle: Text(
                  _expiryDate == null
                      ? 'Select expiry date'
                      : DateFormat('MMM dd, yyyy').format(_expiryDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(false),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveLicense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save License'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
