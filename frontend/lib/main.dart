import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/expiry_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service on app startup
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    // Request notification permission if not already granted
    await notificationService.requestNotificationPermission();
    
    // Initialize expiry notification service for vehicle permit expiry checks
    // This will automatically check for expiring permits every 6 hours
    await ExpiryNotificationService().initialize();
  } catch (e) {
    // Silently handle errors - notifications might not work on all platforms (e.g., Windows)
    debugPrint('Notification initialization error: $e');
  }
  
  runApp(const Company360App());
}

class Company360App extends StatelessWidget {
  const Company360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Company360',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF4AC2B)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}


