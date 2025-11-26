import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Environment configuration for the app
/// 
/// This file reads environment variables, config file, or uses defaults
/// For production, set environment variables or update config.json
class EnvConfig {
  // API Base URL - will be loaded from config file or environment
  static String? _cachedBaseUrl;
  static bool _initialized = false;
  
  // Default values
  // Production Railway URL - used when no config file or environment variable is set
  static const String _productionBaseUrl = 'https://central360-backend-production.up.railway.app';
  static const String _developmentBaseUrl = 'http://localhost:4000';
  static const String _defaultEnvironment = 'development';
  
  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: _defaultEnvironment,
  );

  // Check if running in production
  static bool get isProduction => environment == 'production';

  /// Initialize config - call this at app startup
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Try to read from config file (for installed apps)
      final configUrl = await _readConfigFile();
      if (configUrl != null && configUrl.isNotEmpty) {
        _cachedBaseUrl = configUrl;
        _initialized = true;
        debugPrint('Config loaded from file: $_cachedBaseUrl');
        return;
      }
    } catch (e) {
      debugPrint('Could not read config file: $e');
    }
    
    // Try environment variable (for builds with --dart-define)
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      _cachedBaseUrl = envUrl;
      _initialized = true;
      debugPrint('Config loaded from environment: $_cachedBaseUrl');
      return;
    }
    
    // Use default based on environment
    // For production builds (release mode), use Railway URL
    // For development (debug mode), use localhost
    if (kReleaseMode) {
      _cachedBaseUrl = _productionBaseUrl;
      debugPrint('Using production default (Railway): $_cachedBaseUrl');
    } else {
      _cachedBaseUrl = _developmentBaseUrl;
      debugPrint('Using development default (localhost): $_cachedBaseUrl');
    }
    _initialized = true;
  }
  
  /// Get API base URL (synchronous - must call initialize() first)
  static String get apiBaseUrl {
    if (!_initialized) {
      debugPrint('Warning: EnvConfig not initialized, using default');
      return kReleaseMode ? _productionBaseUrl : _developmentBaseUrl;
    }
    return _cachedBaseUrl ?? (kReleaseMode ? _productionBaseUrl : _developmentBaseUrl);
  }

  /// Read API URL from config.json file
  static Future<String?> _readConfigFile() async {
    try {
      if (kIsWeb) return null; // Web doesn't support file system
      
      Directory appDir;
      if (Platform.isWindows) {
        // For Windows, use AppData\Local\Company360
        final appDataPath = Platform.environment['LOCALAPPDATA'];
        if (appDataPath == null) return null;
        appDir = Directory('$appDataPath\\Company360');
      } else if (Platform.isAndroid) {
        appDir = await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        appDir = await getApplicationDocumentsDirectory();
      } else {
        appDir = await getApplicationSupportDirectory();
      }
      
      // Create directory if it doesn't exist
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      
      final configFile = File('${appDir.path}/config.json');
      
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final config = jsonDecode(content) as Map<String, dynamic>;
        return config['apiBaseUrl'] as String?;
      }
    } catch (e) {
      debugPrint('Error reading config file: $e');
    }
    
    return null;
  }
  
  /// Write API URL to config file
  static Future<void> writeConfigFile(String apiUrl) async {
    try {
      if (kIsWeb) return; // Web doesn't support file system
      
      Directory appDir;
      if (Platform.isWindows) {
        final appDataPath = Platform.environment['LOCALAPPDATA'];
        if (appDataPath == null) return;
        appDir = Directory('$appDataPath\\Company360');
      } else if (Platform.isAndroid) {
        appDir = await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        appDir = await getApplicationDocumentsDirectory();
      } else {
        appDir = await getApplicationSupportDirectory();
      }
      
      // Create directory if it doesn't exist
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      
      final configFile = File('${appDir.path}/config.json');
      final config = {
        'apiBaseUrl': apiUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      await configFile.writeAsString(jsonEncode(config));
      _cachedBaseUrl = apiUrl; // Update cache
      debugPrint('Config file written: ${configFile.path}');
    } catch (e) {
      debugPrint('Error writing config file: $e');
    }
  }

  // Get API endpoint (synchronous)
  static String get apiEndpoint => '$apiBaseUrl/api/v1';
}

