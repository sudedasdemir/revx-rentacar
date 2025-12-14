import 'dart:async';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/home_screen.dart';
import 'package:firebase_app/screens/onboarding_feature/presentation/screen/onboarding_screen.dart';
import 'package:firebase_app/firebase_options.dart';
import 'package:firebase_app/gen/fonts.gen.dart';
import 'package:firebase_app/screens/forgot_email_screen.dart';
import 'package:firebase_app/screens/forgot_password_screen.dart';
import 'package:firebase_app/screens/signup_screen.dart';
import 'package:firebase_app/screens/login_screen.dart';
import 'package:firebase_app/screens/welcome_screen.dart';
import 'package:firebase_app/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app/routes/routes.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app/screens/booking_screen.dart';
import 'package:firebase_app/admin/screens/admin_panel_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/tabs/profile_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:firebase_app/admin/routes/admin_routes.dart';
import 'package:firebase_app/services/notification_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize OneSignal first
  OneSignal.initialize(NotificationService.oneSignalAppId);
  await OneSignal.User.pushSubscription.optIn();

  // Then initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Save the OneSignal user ID
  await NotificationService().saveUserDeviceToken();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(isDarkMode: isDark),
      child: const MyApp(),
    ),
  );
}

class FavoriteCarProvider {}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'RevX',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: Colors.red,
          secondary: Colors.redAccent,
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Colors.red,
          secondary: Colors.redAccent,
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      supportedLocales: [Locale('en', 'US'), Locale('tr', 'TR')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: {...appRoutes, ...AdminRoutes.getRoutes()},
      home: LoginScreen(),
    );
  }
}
