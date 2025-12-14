import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/widgets/custom_text_field.dart';
import 'package:firebase_app/widgets/social_login_button.dart';
import 'package:firebase_app/widgets/gradient_button.dart';
import 'package:firebase_app/theme/theme.dart';
import 'package:firebase_app/services/auth/auth_service.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verify_email_screen.dart';
import 'package:flutter/services.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _firmCodeController = TextEditingController();
  final _authorizedPersonController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isCorporate = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _firmCodeController.dispose();
    _authorizedPersonController.dispose();
    _companyAddressController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      User? user = await AuthService().signInWithGoogle();
      if (user == null) {
        throw Exception("Google sign-in returned null user.");
      }

      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'role': 'user',
          'totalSpent': 0,
          'userTier': 'silver',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In failed. Please try again.")),
      );
      print("Google Sign-In Error: $e");
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get the values from controllers
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final firmCode = _firmCodeController.text.trim();
      final authorizedPerson = _authorizedPersonController.text.trim();
      final companyAddress = _companyAddressController.text.trim();

      // Create user with email and password
      final userCredential = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Add user data to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'fullName':
                  _isCorporate ? name : name, // Company name for corporate
              'email': email,
              'totalSpent': 0,
              'userTier': 'silver',
              'role': _isCorporate ? 'corporate' : 'user',
              'firmCode': _isCorporate ? firmCode : null,
              'authorizedPerson': _isCorporate ? authorizedPerson : null,
              'companyAddress': _isCorporate ? companyAddress : null,
              'createdAt': FieldValue.serverTimestamp(),
            });
        await _authService.sendEmailVerification();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A verification email has been sent. Please check your inbox.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        if (mounted) {
          // Navigate to email verification screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Sign up error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPasswordAlert(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create Strong Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                const Text(
                  'Password Requirements:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• At least 6 characters long'),
                const Text('• Must contain at least one number'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height * 0.22,
                        decoration: BoxDecoration(
                          color:
                              isDarkMode
                                  ? AppColors.secondary
                                  : AppColors.secondary,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -50,
                              right: -50,
                              child: Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 40,
                              left: 16,
                              right: 16,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.arrow_back,
                                      color:
                                          isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                        'Create Account',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Create your account",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Sign up to start your renting journey",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Toggle for Individual/Corporate
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              !_isCorporate
                                                  ? AppColors.primary
                                                  : Colors.grey[200],
                                          foregroundColor:
                                              !_isCorporate
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
                                            _isCorporate = false;
                                          });
                                        },
                                        child: const Text('Individual'),
                                      ),
                                    ),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              _isCorporate
                                                  ? AppColors.primary
                                                  : Colors.grey[200],
                                          foregroundColor:
                                              _isCorporate
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
                                            _isCorporate = true;
                                          });
                                        },
                                        child: const Text('Corporate'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                CustomTextField(
                                  controller: _nameController,
                                  label:
                                      _isCorporate
                                          ? "Company Name"
                                          : "Full Name",
                                  isPassword: false,
                                  prefixIcon: Icons.person_outline,
                                  keyboardType: TextInputType.text,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return _isCorporate
                                          ? 'Please enter company name'
                                          : 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (_isCorporate) ...[
                                  CustomTextField(
                                    controller: _firmCodeController,
                                    label: "Tax ID / VKN",
                                    isPassword: false,
                                    prefixIcon: Icons.business,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: (value) {
                                      if (!_isCorporate) return null;
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your Tax ID / VKN';
                                      }
                                      if (value.length != 10) {
                                        return 'Tax ID / VKN must be exactly 10 digits';
                                      }
                                      if (!RegExp(
                                        r'^\d{10}$',
                                      ).hasMatch(value)) {
                                        return 'Tax ID / VKN can only contain numbers';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    controller: _authorizedPersonController,
                                    label: "Authorized Person Full Name",
                                    isPassword: false,
                                    prefixIcon: Icons.person,
                                    keyboardType: TextInputType.name,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z\s]'),
                                      ),
                                    ],
                                    validator: (value) {
                                      if (!_isCorporate) return null;
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter authorized person name';
                                      }
                                      if (!RegExp(
                                        r'^[a-zA-Z\s]+$',
                                      ).hasMatch(value)) {
                                        return 'Name can only contain letters and spaces';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    controller: _companyAddressController,
                                    label: "Company Address",
                                    isPassword: false,
                                    prefixIcon: Icons.location_on,
                                    keyboardType: TextInputType.streetAddress,
                                    validator: (value) {
                                      if (!_isCorporate) return null;
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter company address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                CustomTextField(
                                  controller: _emailController,
                                  label: "Email",
                                  isPassword: false,
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null ||
                                        value.isEmpty ||
                                        !value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _passwordController,
                                  label: "Password",
                                  isPassword: !_showPassword,
                                  prefixIcon: Icons.lock_outline,
                                  keyboardType: TextInputType.visiblePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _showPassword = !_showPassword,
                                      );
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (value.length < 6) {
                                      _showPasswordAlert(
                                        'Password must be at least 6 characters long',
                                      );
                                      return 'Password must be at least 6 characters';
                                    }
                                    if (!value.contains(RegExp(r'[0-9]'))) {
                                      _showPasswordAlert(
                                        'Password must contain at least one number',
                                      );
                                      return 'Password must contain a number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _confirmPasswordController,
                                  label: "Confirm Password",
                                  isPassword: !_showConfirmPassword,
                                  prefixIcon: Icons.lock_outline,
                                  keyboardType: TextInputType.visiblePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () =>
                                            _showConfirmPassword =
                                                !_showConfirmPassword,
                                      );
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                GradientButton(
                                  text:
                                      _isLoading
                                          ? "Creating Account..."
                                          : "Create Account",
                                  onPressed: () {
                                    if (!_isLoading) {
                                      _signUp();
                                    }
                                  },
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: Text(
                                    "Or continue with",
                                    style: TextStyle(
                                      color:
                                          isDarkMode
                                              ? Colors.white
                                              : AppTheme.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SocialLoginButton(
                                  text: "Google",
                                  isPassword: false,
                                  iconPath: 'assets/icons/google.png',
                                  onPressed: _signInWithGoogle,
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Already have an account?",
                                        style: TextStyle(
                                          color:
                                              isDarkMode
                                                  ? Colors.white
                                                  : AppTheme.textSecondary,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const LoginScreen(),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              isDarkMode
                                                  ? Colors.white
                                                  : AppColors.black,
                                        ),
                                        child: const Text('Login'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
