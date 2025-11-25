import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import '../config/env_config.dart';

class UpdateService {
  static const String _versionEndpoint = '/api/v1/app/version';
  
  /// Check if a new version is available
  /// Returns [UpdateInfo] if update is available, null otherwise
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
      
      debugPrint('Current app version: $currentVersion+$currentBuildNumber');
      
      // Check latest version from backend
      final response = await http.get(
        Uri.parse('${EnvConfig.apiBaseUrl}$_versionEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'] as String;
        final latestBuildNumber = int.tryParse(data['buildNumber'] ?? '1') ?? 1;
        final downloadUrl = data['downloadUrl'] as String?;
        final releaseNotes = data['releaseNotes'] as String?;
        final isRequired = data['isRequired'] as bool? ?? false;
        
        debugPrint('Latest version: $latestVersion+$latestBuildNumber');
        
        // Compare versions
        if (_isNewerVersion(latestVersion, latestBuildNumber, currentVersion, currentBuildNumber)) {
          return UpdateInfo(
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
            latestVersion: latestVersion,
            latestBuildNumber: latestBuildNumber,
            downloadUrl: downloadUrl ?? '',
            releaseNotes: releaseNotes ?? 'Bug fixes and improvements',
            isRequired: isRequired,
          );
        }
      } else {
        debugPrint('Failed to check for updates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      // Don't show error to user - silent fail
    }
    
    return null;
  }
  
  /// Compare version strings and build numbers
  static bool _isNewerVersion(
    String latestVersion,
    int latestBuildNumber,
    String currentVersion,
    int currentBuildNumber,
  ) {
    // Compare build numbers first (more reliable)
    if (latestBuildNumber > currentBuildNumber) {
      return true;
    }
    
    // If build numbers are equal, compare version strings
    if (latestBuildNumber == currentBuildNumber) {
      final latestParts = latestVersion.split('.').map(int.tryParse).toList();
      final currentParts = currentVersion.split('.').map(int.tryParse).toList();
      
      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        final latest = latestParts[i] ?? 0;
        final current = currentParts[i] ?? 0;
        if (latest > current) return true;
        if (latest < current) return false;
      }
      
      // If all parts are equal, latest is longer
      return latestParts.length > currentParts.length;
    }
    
    return false;
  }
  
  /// Download the update installer
  static Future<String?> downloadUpdate(String downloadUrl, Function(int, int) onProgress) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }
      
      // Get file name from URL or use default
      final fileName = downloadUrl.split('/').last;
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      
      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int downloaded = 0;
      
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        onProgress(downloaded, contentLength);
      }
      
      await file.writeAsBytes(bytes);
      debugPrint('Update downloaded to: ${file.path}');
      
      return file.path;
    } catch (e) {
      debugPrint('Error downloading update: $e');
      rethrow;
    }
  }
  
  /// Launch the installer (Windows only)
  static Future<void> installUpdate(String installerPath) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Auto-install only supported on Windows');
    }
    
    try {
      // Launch installer - Windows will prompt for admin permission if needed
      // Using start command to open in a new window
      await Process.run(
        'cmd',
        ['/c', 'start', '', installerPath],
        runInShell: true,
      );
    } catch (e) {
      debugPrint('Error launching installer: $e');
      // Try alternative method
      try {
        await Process.start(installerPath, [], mode: ProcessStartMode.detached);
      } catch (e2) {
        debugPrint('Alternative launch method also failed: $e2');
        rethrow;
      }
    }
  }
}

class UpdateInfo {
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool isRequired;
  
  UpdateInfo({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isRequired,
  });
  
  String get versionString => '$latestVersion+$latestBuildNumber';
}

