/// Environment configuration for the app
/// 
/// This file reads environment variables or uses defaults
/// For production, set environment variables or update defaults
class EnvConfig {
  // API Base URL
  // For development: http://localhost:4000 or http://10.0.2.2:4000 (Android emulator)
  // For production: https://your-api-domain.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // Check if running in production
  static bool get isProduction => environment == 'production';

  // Get API base URL with protocol
  static String get apiBaseUrl {
    const url = baseUrl;
    // Ensure URL doesn't end with slash
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // Get API endpoint
  static String get apiEndpoint => '$apiBaseUrl/api/v1';
}

