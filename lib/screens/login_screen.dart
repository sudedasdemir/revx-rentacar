import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/widgets/custom_text_field.dart';
import 'package:firebase_app/widgets/social_login_button.dart';
import 'package:firebase_app/widgets/gradient_button.dart';
import 'package:firebase_app/theme/theme.dart';
import 'package:firebase_app/screens/forgot_password_screen.dart';
import 'package:firebase_app/screens/signup_screen.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/home_screen.dart';
import 'package:firebase_app/services/auth/auth_service.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/admin/screens/admin_panel_screen.dart';
import 'package:firebase_app/screens/verify_email_screen.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _retailFormKey = GlobalKey<FormState>();
  final _corporateFormKey = GlobalKey<FormState>();
  final TextEditingController firmCodeController = TextEditingController();
  final TextEditingController retailUserController = TextEditingController();
  final TextEditingController retailPasswordController =
      TextEditingController();
  final TextEditingController corpUserController = TextEditingController();
  final TextEditingController corpPasswordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool passToggle = true;
  String? formError;
  int failedAttempts = 0;
  bool showPasswordWarning = false;
  bool _showVerifyEmailButton = false;
  final AuthService _authService = AuthService();
  bool isCorporate = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    retailUserController.addListener(_validateRetailUser);
    retailPasswordController.addListener(_validateRetailPassword);
    corpUserController.addListener(_validateCorporateUser);
    corpPasswordController.addListener(_validateCorporatePassword);
    emailController.addListener(_validateEmail);
    passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _tabController.dispose();
    firmCodeController.dispose();
    retailUserController.removeListener(_validateRetailUser);
    retailPasswordController.removeListener(_validateRetailPassword);
    corpUserController.removeListener(_validateCorporateUser);
    corpPasswordController.removeListener(_validateCorporatePassword);
    emailController.removeListener(_validateEmail);
    passwordController.removeListener(_validatePassword);
    retailUserController.dispose();
    retailPasswordController.dispose();
    corpUserController.dispose();
    corpPasswordController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _validateRetailUser() {
    setState(() {
      final user = retailUserController.text.trim();
      if (user.isEmpty) {
        formError = 'Please enter your TR ID or User ID';
      } else {
        formError = null;
      }
    });
  }

  void _validateRetailPassword() {
    setState(() {
      final password = retailPasswordController.text;
      if (password.isEmpty) {
        formError = 'Please enter your password';
      } else if (password.length < 6) {
        formError = 'Password must be at least 6 characters';
      } else {
        formError = null;
      }
    });
  }

  void _validateCorporateUser() {
    setState(() {
      final user = corpUserController.text.trim();
      if (user.isEmpty) {
        formError = 'Please enter your User Code';
      } else {
        formError = null;
      }
    });
  }

  void _validateCorporatePassword() {
    setState(() {
      final password = corpPasswordController.text;
      if (password.isEmpty) {
        formError = 'Please enter your password';
      } else if (password.length < 6) {
        formError = 'Password must be at least 6 characters';
      } else {
        formError = null;
      }
    });
  }

  void _validateEmail() {
    setState(() {
      final email = emailController.text.trim();
      if (email.isEmpty) {
        formError = 'Please enter your email';
      } else if (!email.contains('@')) {
        formError = 'Please enter a valid email';
      } else {
        formError = null;
      }
    });
  }

  void _validatePassword() {
    setState(() {
      final password = passwordController.text;
      if (password.isEmpty) {
        formError = 'Please enter your password';
      } else if (password.length < 6) {
        formError = 'Password must be at least 6 characters';
      } else {
        formError = null;
      }
    });
  }

  void signInGoogleAndNavigate() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      print("Starting Google sign-in process..."); // Debug log

      // Attempt to sign in with Google
      User? user = await AuthService().signInWithGoogle();
      print(
        "Google sign-in result: ${user != null ? "Success" : "Failed"}",
      ); // Debug log

      // Dismiss the loading indicator
      if (context.mounted) Navigator.pop(context);

      if (user == null) {
        // User cancelled the sign-in
        setState(() {
          formError = "Sign-in was cancelled. Please try again.";
        });
        return;
      }

      // Navigate to HomeScreen
      if (context.mounted) {
        print("Checking admin status for user: ${user.uid}"); // Debug log

        // Check if user is admin
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        final isAdmin = doc.data()?['isAdmin'] == true;
        print("Admin status: $isAdmin"); // Debug log

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (context) =>
                    isAdmin ? const AdminPanelScreen() : const HomeScreen(),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}"); // Debug log

      // Dismiss the loading indicator
      if (context.mounted) Navigator.pop(context);

      // Show specific error message based on the error code
      setState(() {
        switch (e.code) {
          case 'account-exists-with-different-credential':
            formError =
                "An account already exists with the same email address but different sign-in credentials.";
            break;
          case 'invalid-credential':
            formError = "The sign-in credentials are invalid.";
            break;
          case 'operation-not-allowed':
            formError =
                "Google sign-in is not enabled. Please contact support.";
            break;
          case 'user-disabled':
            formError =
                "This account has been disabled. Please contact support.";
            break;
          case 'user-not-found':
            formError = "No account found with these credentials.";
            break;
          case 'network-request-failed':
            formError = "Network error. Please check your internet connection.";
            break;
          default:
            formError = "An error occurred during sign-in. Please try again.";
        }
      });
    } catch (e) {
      print("Unexpected Error during Google Sign-In: $e"); // Debug log

      // Dismiss the loading indicator
      if (context.mounted) Navigator.pop(context);

      // Show generic error message
      setState(() {
        formError = "An unexpected error occurred. Please try again.";
      });
    }
  }

  void signUserIn() async {
    setState(() {
      formError = null;
    });

    if (!_retailFormKey.currentState!.validate()) return;

    try {
      final userCredential = await _authService.signIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      // Reset failed attempts on successful login
      setState(() {
        failedAttempts = 0;
        showPasswordWarning = false;
      });

      if (userCredential != null) {
        bool isVerified = await _authService.isEmailVerified();

        if (isVerified) {
          // Email verified, go to HomeScreen
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
        } else {
          // Show warning dialog for unverified email
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Email Verification Required'),
                    content: const Text(
                      'Please verify your email address before logging in. A verification email has been sent to your inbox.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const VerifyEmailScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Verify Email'),
                      ),
                    ],
                  ),
            );
          }
        }
      }
    } catch (e) {
      print('Login error: $e'); // Debug print
      setState(() {
        failedAttempts++;
        if (failedAttempts >= 3) {
          showPasswordWarning = true;
        }
        if (e.toString().contains('wrong-password') ||
            e.toString().contains('invalid-credential')) {
          formError = "Please enter your correct password. Try again.";
        } else if (e.toString().contains('email-not-verified')) {
          formError = "Please verify your email before logging in.";
        } else {
          formError = _authService.getErrorMessage(e.toString());
        }
      });
    }
  }

  void _loginRetail() {
    if (_retailFormKey.currentState!.validate()) {
      // TODO: Implement retail login logic
    }
  }

  void _loginCorporate() {
    if (_corporateFormKey.currentState!.validate()) {
      // TODO: Implement corporate login logic
    }
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  Future<void> _saveUserToFirestore(User user) async {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Background gradient and header
            Container(
              height: MediaQuery.of(context).size.height * 0.22,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.primary
                        : AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Center(
                child: Text(
                  'Welcome Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Login form
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.15,
                left: 24,
                right: 24,
                bottom: 24,
              ),
              child: Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.backgroundDark
                          : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _retailFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Restore login title and subtitle
                      Text(
                        "Login to your account",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.whiteColor
                                  : AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Enter your credentials to continue renting",
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.textSecondary
                                  : AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: 16),
                      // Toggle for Individual/Corporate
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    !isCorporate
                                        ? AppColors.primary
                                        : Colors.grey[200],
                                foregroundColor:
                                    !isCorporate
                                        ? Colors.white
                                        : AppColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  isCorporate = false;
                                  formError = null;
                                });
                              },
                              child: const Text('Individual'),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isCorporate
                                        ? AppColors.primary
                                        : Colors.grey[200],
                                foregroundColor:
                                    isCorporate
                                        ? Colors.white
                                        : AppColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  isCorporate = true;
                                  formError = null;
                                });
                              },
                              child: const Text('Corporate'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (formError != null) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppColors.error),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formError!,
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (showPasswordWarning) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Have you forgotten your password?",
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showPasswordWarning = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              TextButton(
                                onPressed: _navigateToForgotPassword,
                                child: Text(
                                  "Click to reset",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_showVerifyEmailButton) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  "Your email is not verified. Please check your inbox and click the verification link.",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    if (user != null && !user.emailVerified) {
                                      await user.sendEmailVerification();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Verification email has been resent.',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    "Resend verification email",
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 32),
                      if (isCorporate) ...[
                        TextFormField(
                          controller: firmCodeController,
                          decoration: InputDecoration(
                            labelText: "Tax ID/VKN",
                            prefixIcon: Icon(Icons.business, color: Colors.red),
                            labelStyle: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppColors.error,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppColors.error,
                                width: 1,
                              ),
                            ),
                            errorStyle: TextStyle(
                              height: 0,
                            ), // Hide the default error text
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (!isCorporate) return null;
                            if (value == null || value.isEmpty)
                              return "Tax ID/VKN is required";
                            if (!RegExp(r'^[0-9]{10}').hasMatch(value))
                              return "Tax ID/VKN must be exactly 10 digits";
                            return null;
                          },
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                      CustomTextField(
                        controller: emailController,
                        label: "Email",
                        isPassword: false,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a valid email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      CustomTextField(
                        controller: passwordController,
                        label: "Password",
                        prefixIcon: Icons.lock_outline,
                        keyboardType: TextInputType.visiblePassword,
                        isPassword: passToggle,
                        suffixIcon: IconButton(
                          icon: Icon(
                            passToggle
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => passToggle = !passToggle);
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _navigateToForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: Text("Forgot Password"),
                        ),
                      ),
                      SizedBox(height: 24),
                      GradientButton(text: "Login", onPressed: signUserIn),
                      if (!isCorporate) ...[
                        SizedBox(height: 24),
                        Center(
                          child: Text(
                            "Or continue with",
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondary
                                      : AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Image.asset(
                                  'assets/icons/google.png',
                                  height: 24,
                                  width: 24,
                                ),
                                label: const Text('Google'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  side: BorderSide(
                                    color: AppColors.primary,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: signInGoogleAndNavigate,
                              ),
                            ),
                          ],
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondary
                                      : AppTheme.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignupScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                            child: Text('Sign Up'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
