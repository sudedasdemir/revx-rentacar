import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String? Name;
  final String? email;
  final String? phone;
  final String? address;
  final String? profileImageUrl;
  final LicenseInfo? licenseInfo;
  final bool isCorporate;
  final String? companyName;
  final String? taxId;
  final String? authorizedPerson;
  final String? firmCode;
  final String? companySector;

  UserProfile({
    this.Name,
    this.email,
    this.phone,
    this.address,
    this.profileImageUrl,
    this.licenseInfo,
    this.isCorporate = false,
    this.companyName,
    this.taxId,
    this.authorizedPerson,
    this.firmCode,
    this.companySector,
  });

  bool get isProfileComplete {
    if (isCorporate) {
      return companyName != null &&
          companyName!.isNotEmpty &&
          taxId != null &&
          taxId!.isNotEmpty &&
          authorizedPerson != null &&
          authorizedPerson!.isNotEmpty &&
          firmCode != null &&
          firmCode!.isNotEmpty &&
          companySector != null &&
          companySector!.isNotEmpty &&
          phone != null &&
          phone!.isNotEmpty &&
          address != null &&
          address!.isNotEmpty;
    } else {
      return Name != null &&
          Name!.isNotEmpty &&
          phone != null &&
          phone!.isNotEmpty &&
          address != null &&
          address!.isNotEmpty;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'Name': Name,
      'email': email,
      'phone': phone,
      'address': address,
      'profileImageUrl': profileImageUrl,
      'isCorporate': isCorporate,
      'companyName': companyName,
      'taxId': taxId,
      'authorizedPerson': authorizedPerson,
      'firmCode': firmCode,
      'companySector': companySector,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static UserProfile fromMap(
    Map<String, dynamic> map, {
    LicenseInfo? licenseInfo,
  }) {
    return UserProfile(
      Name: map['Name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      licenseInfo: licenseInfo,
      isCorporate: map['isCorporate'] as bool? ?? false,
      companyName: map['companyName'] as String?,
      taxId: map['taxId'] as String?,
      authorizedPerson: map['authorizedPerson'] as String?,
      firmCode: map['firmCode'] as String?,
      companySector: map['companySector'] as String?,
    );
  }
}

class LicenseInfo {
  final String? licenseNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? Class;

  LicenseInfo({
    this.licenseNumber,
    this.issueDate,
    this.expiryDate,
    this.Class,
  });

  bool get isComplete =>
      licenseNumber != null &&
      licenseNumber!.isNotEmpty &&
      issueDate != null &&
      expiryDate != null &&
      Class != null &&
      Class!.isNotEmpty;

  bool get isValid {
    if (issueDate == null) return false;
    final today = DateTime.now();
    final licenseAge = today.difference(issueDate!);
    final licenseAgeInYears = licenseAge.inDays / 365;
    return licenseAgeInYears >= 2 &&
        expiryDate != null &&
        expiryDate!.isAfter(today);
  }

  Map<String, dynamic> toMap() {
    return {
      'licenseNumber': licenseNumber,
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'Class': Class,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static LicenseInfo? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return LicenseInfo(
      licenseNumber: map['licenseNumber'] as String?,
      issueDate:
          map['issueDate'] != null
              ? (map['issueDate'] as Timestamp).toDate()
              : null,
      expiryDate:
          map['expiryDate'] != null
              ? (map['expiryDate'] as Timestamp).toDate()
              : null,
      Class: map['Class'] as String?,
    );
  }
}

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserProfile?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final isCorporate = userData['role'] == 'corporate';

      // Get license data
      final licenseDoc =
          await _firestore.collection('licenseExpiry').doc(user.uid).get();
      final licenseInfo = LicenseInfo.fromMap(licenseDoc.data());

      return UserProfile.fromMap(userData, licenseInfo: licenseInfo);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<bool> isLicenseValid() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final licenseDoc =
          await _firestore.collection('licenseExpiry').doc(user.uid).get();
      if (!licenseDoc.exists) return false;

      final licenseInfo = LicenseInfo.fromMap(licenseDoc.data());
      return licenseInfo?.isValid ?? false;
    } catch (e) {
      print('Error checking license validity: $e');
      return false;
    }
  }

  Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Update user data
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profile.toMap(), SetOptions(merge: true));

      // Update license data if provided
      if (profile.licenseInfo != null) {
        await _firestore
            .collection('licenseExpiry')
            .doc(user.uid)
            .set(profile.licenseInfo!.toMap(), SetOptions(merge: true));
      }

      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  Stream<UserProfile?> userProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore.collection('users').doc(user.uid).snapshots().asyncMap((
      userSnapshot,
    ) async {
      if (!userSnapshot.exists) return null;

      final licenseDoc =
          await _firestore.collection('licenseExpiry').doc(user.uid).get();

      final licenseInfo = LicenseInfo.fromMap(licenseDoc.data());
      return UserProfile.fromMap(
        userSnapshot.data()!,
        licenseInfo: licenseInfo,
      );
    });
  }

  Future<LicenseInfo?> getLicenseInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final licenseDoc =
          await _firestore.collection('licenseExpiry').doc(user.uid).get();

      if (!licenseDoc.exists) return null;

      return LicenseInfo.fromMap(licenseDoc.data());
    } catch (e) {
      print('Error getting license info: $e');
      return null;
    }
  }
}
