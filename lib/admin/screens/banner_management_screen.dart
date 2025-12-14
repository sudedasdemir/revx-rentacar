import 'package:firebase_app/features/home_feature/data/models/banner_model.dart';
import 'package:firebase_app/features/home_feature/data/repositories/banner_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BannerManagementScreen extends StatefulWidget {
  const BannerManagementScreen({Key? key}) : super(key: key);

  @override
  State<BannerManagementScreen> createState() => _BannerManagementScreenState();
}

class _BannerManagementScreenState extends State<BannerManagementScreen> {
  final BannerRepository _repository = BannerRepository();
  bool isUploading = false;
  final _urlController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  String? _selectedCarId;

  String _formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  Future<void> _showAddBannerDialog() {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Banner'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Upload from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _addBannerFromGallery();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Add from URL'),
                  onTap: () {
                    Navigator.pop(context);
                    _showUrlInputDialog();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showUrlInputDialog() {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Banner URL'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'Enter image URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('cars')
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final cars = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: _selectedCarId,
                        decoration: const InputDecoration(
                          labelText: 'Select Car (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No Car'),
                          ),
                          ...cars.map((car) {
                            final data = car.data() as Map<String, dynamic>;
                            final brand = data['brand'] as String? ?? 'Unknown';
                            final name = data['name'] as String? ?? 'Unknown';
                            return DropdownMenuItem<String>(
                              value: car.id,
                              child: Text('$brand $name'),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCarId = value;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _urlController.clear();
                  setState(() {
                    _selectedCarId = null;
                  });
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (_urlController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _addBannerFromUrl(_urlController.text);
                    _urlController.clear();
                    setState(() {
                      _selectedCarId = null;
                    });
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _addBannerFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => isUploading = true);
    try {
      final file = pickedFile;
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child('banners/$fileName');
      await ref.putData(await file.readAsBytes());
      final url = await ref.getDownloadURL();

      await _repository.addBanner(url, carId: _selectedCarId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding banner: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  Future<void> _addBannerFromUrl(String url) async {
    setState(() => isUploading = true);
    try {
      await _repository.addBanner(url, carId: _selectedCarId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding banner: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  Future<void> _deleteBanner(BannerModel banner) async {
    try {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Delete Banner'),
              content: const Text(
                'Are you sure you want to delete this banner?',
              ),
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

      if (shouldDelete != true) return;

      await _repository.deleteBanner(banner.id);

      if (banner.imageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(banner.imageUrl);
          await ref.delete();
        } catch (storageError) {
          print('Error deleting from storage: $storageError');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting banner: $e')));
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Banners'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon:
                isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.add_photo_alternate),
            onPressed: isUploading ? null : _showAddBannerDialog,
            tooltip: 'Add Banner',
          ),
        ],
      ),
      body: StreamBuilder<List<BannerModel>>(
        stream: _repository.getBanners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No banners found.'));
          }

          final banners = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.error_outline, size: 40),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Banner ${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Added: ${_formatDate(banner.createdAt)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: () => _deleteBanner(banner),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
