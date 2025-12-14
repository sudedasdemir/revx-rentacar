import 'package:flutter/material.dart';

class CorporateCancellationFormPage extends StatefulWidget {
  const CorporateCancellationFormPage({super.key});

  @override
  _CorporateCancellationFormPageState createState() =>
      _CorporateCancellationFormPageState();
}

class _CorporateCancellationFormPageState
    extends State<CorporateCancellationFormPage> {
  // Global key for the form
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _reservationNumberController =
      TextEditingController();
  final TextEditingController _cancellationReasonController =
      TextEditingController();

  // Dropdown values for cancellation reason
  final List<String> _cancellationReasons = [
    'Change of plans',
    'Better price found',
    'Didn’t need the car anymore',
    'Other',
  ];
  String? _selectedReason;

  // File picker variable (for optional document upload)
  String? _document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Corporate Cancellation Form")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Company Name field
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(labelText: 'Company Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the company name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Tax Number field
              TextFormField(
                controller: _taxNumberController,
                decoration: const InputDecoration(labelText: 'Tax Number'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the tax number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Contact Person field
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(labelText: 'Contact Person'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the contact person\'s name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Email field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  } else if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Phone Number field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Reservation Number field
              TextFormField(
                controller: _reservationNumberController,
                decoration: const InputDecoration(
                  labelText: 'Reservation Number',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your reservation number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Cancellation Reason dropdown
              DropdownButtonFormField<String>(
                value: _selectedReason,
                hint: const Text('Select a reason'),
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
                items:
                    _cancellationReasons.map((reason) {
                      return DropdownMenuItem<String>(
                        value: reason,
                        child: Text(reason),
                      );
                    }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a cancellation reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Cancellation Description field
              TextFormField(
                controller: _cancellationReasonController,
                decoration: const InputDecoration(
                  labelText: 'Describe the reason (Optional)',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              // File Upload section (Optional)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Upload Supporting Documents (Optional)'),
                  ElevatedButton(
                    onPressed: () async {
                      // Here, you can integrate a file picker library or logic to upload a document
                      // For simplicity, this will just simulate a document selection
                      setState(() {
                        _document =
                            "uploaded_document.pdf"; // Simulated file name
                      });
                    },
                    child: const Text('Upload'),
                  ),
                ],
              ),
              if (_document != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text('Uploaded Document: $_document'),
                ),
              const SizedBox(height: 20),

              // Submit button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Process data if the form is valid
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Processing your cancellation'),
                      ),
                    );
                    // Perform further actions (e.g., send data to the server)
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
