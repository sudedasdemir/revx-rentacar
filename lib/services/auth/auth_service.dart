import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Get the current user
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  // Email sign-in
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      // Sign the user in
      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      // After successful login, check if the user is an admin
      bool isAdmin = await _checkIfAdmin(userCredential.user!.uid);
      if (isAdmin) {
        print("Admin login successful");
      } else {
        print("User is not an admin");
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code); // Pass the error code for better handling
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Email sign-up
  Future<UserCredential> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      // Create a new user
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code); // Pass the error code for better handling
    }
  }

  // Sign out
  Future<void> signOut() async {
    return await _firebaseAuth.signOut();
  }

  // Google sign-in
  Future<User?> signInWithGoogle() async {
    try {
      print("Starting Google Sign-In process..."); // Debug log

      // Begin the interactive sign-in process
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
      print("Google Sign-In Account: ${gUser?.email}"); // Debug log

      // If the user cancels the Google sign-in pop-up
      if (gUser == null) {
        print("Google Sign-In was cancelled by the user");
        return null;
      }

      // Obtain authentication details from the request
      final GoogleSignInAuthentication gAuth = await gUser.authentication;
      print("Got Google Auth tokens"); // Debug log

      if (gAuth.accessToken == null || gAuth.idToken == null) {
        print("Failed to get Google Auth tokens");
        throw Exception("Failed to get Google Auth tokens");
      }

      // Create a new credential for the user
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      print(
        "Attempting Firebase sign-in with Google credential...",
      ); // Debug log

      // Sign in with the credential and return the user
      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);
      print(
        "Firebase sign-in successful: ${userCredential.user?.email}",
      ); // Debug log

      if (userCredential.user == null) {
        print("Firebase Auth returned null user after Google Sign-In");
        throw Exception("Firebase Auth returned null user");
      }

      // Save user to Firestore if needed
      await _saveUserToFirestore(userCredential.user!);
      print("User saved to Firestore successfully"); // Debug log

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print(
        "Firebase Auth Error during Google Sign-In: ${e.code} - ${e.message}",
      );
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
          'An account already exists with the same email address but different sign-in credentials.',
        );
      } else if (e.code == 'invalid-credential') {
        throw Exception('The sign-in credentials are invalid.');
      } else if (e.code == 'operation-not-allowed') {
        throw Exception(
          'Google sign-in is not enabled. Please contact support.',
        );
      } else if (e.code == 'user-disabled') {
        throw Exception(
          'This account has been disabled. Please contact support.',
        );
      } else if (e.code == 'user-not-found') {
        throw Exception('No account found with these credentials.');
      } else if (e.code == 'network-request-failed') {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      }
      throw Exception('An error occurred during Google sign-in: ${e.message}');
    } catch (e) {
      print("Unexpected Error during Google Sign-In: $e");
      throw Exception(
        'An unexpected error occurred during Google sign-in. Please try again.',
      );
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'role': 'user',
          'userTier': 'silver',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last login time
        await userDoc.update({'lastLogin': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      print("Error saving user to Firestore: $e");
      // Don't throw the error as this is not critical for sign-in
    }
  }

  // Check if the user is an admin
  Future<bool> _checkIfAdmin(String userId) async {
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      if (doc.exists) {
        return doc['isAdmin'] ?? false; // Check if 'isAdmin' field exists
      }
      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Possible error messages
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'wrong-password':
        return 'The password is incorrect. Please try again.';
      case 'user-not-found':
        return 'No user found with this email. Please sign up.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      default:
        return 'An unexpected error occurred. Please try again later.';
    }
  }

  // Send verification email to current user
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        print("Verification email sent to ${user.email}");
      } catch (e) {
        print("Error sending verification email: $e");
        throw Exception("Failed to send verification email");
      }
    }
  }

  // Check if user's email is verified
  Future<bool> isEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;

    try {
      await user.reload(); // refresh current user data
      return user.emailVerified;
    } catch (e) {
      print("Error checking email verification: $e");
      return false;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCredential.user!.emailVerified) {
        // If email is not verified, send verification email
        await sendEmailVerification();
        throw Exception('email-not-verified');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }
}

// En sona, en alt satıra ekle
