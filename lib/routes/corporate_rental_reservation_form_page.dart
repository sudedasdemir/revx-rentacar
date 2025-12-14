import 'package:flutter/material.dart';

class CorporateRentalReservationFormPage extends StatefulWidget {
  const CorporateRentalReservationFormPage({super.key});

  @override
  _CorporateRentalReservationFormPageState createState() =>
      _CorporateRentalReservationFormPageState();
}

class _CorporateRentalReservationFormPageState
    extends State<CorporateRentalReservationFormPage> {
  // Form key
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _additionalNotesController =
      TextEditingController();

  // Date pickers
  DateTime? _startDate;
  DateTime? _endDate;

  // Function to pick date
  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
    DateTime? date,
  ) async {
    DateTime initialDate = date ?? DateTime.now();
    DateTime firstDate = DateTime(1900);
    DateTime lastDate = DateTime(2100);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && picked != date) {
      setState(() {
        date = picked;
        controller.text = '${picked.toLocal()}'.split(' ')[0];
      });
    }
  }

  // Submit form
  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      // Process data
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing your reservation request')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Corporate Rental Reservation Form')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Company Name
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the company name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Contact Person
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(
                  labelText: 'Contact Person',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the contact person\'s name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Email Address
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Vehicle Model
              TextFormField(
                controller: _vehicleModelController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Model',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the vehicle model';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Start Date
              TextFormField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: 'Reservation Start Date',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap:
                    () => _pickDate(context, _startDateController, _startDate),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a start date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // End Date
              TextFormField(
                controller: _endDateController,
                decoration: const InputDecoration(
                  labelText: 'Reservation End Date',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: () => _pickDate(context, _endDateController, _endDate),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an end date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Additional Notes
              TextFormField(
                controller: _additionalNotesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Submit'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
