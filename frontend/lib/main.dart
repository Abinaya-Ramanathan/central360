import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/expiry_notification_service.dart';
import 'config/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize config first (loads API URL from config file or environment)
  await EnvConfig.initialize();
  
  // Request all necessary permissions on app startup
  try {
    // Request notification permission
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.requestNotificationPermission();
    
    // Request storage permission (for Android 10 and below)
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    
    // Request photos/gallery permission (for Android 13+)
    if (await Permission.photos.isDenied) {
      await Permission.photos.request();
    }
    
    // Also request manageExternalStorage for Android 11+ if needed
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
    
    // Initialize expiry notification service for vehicle permit expiry checks
    // This will automatically check for expiring permits every 6 hours
    await ExpiryNotificationService().initialize();
  } catch (e) {
    // Silently handle errors - permissions might not work on all platforms (e.g., Windows)
    debugPrint('Permission initialization error: $e');
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


