import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/env_config.dart';

class UpdateService {
  static const String _versionEndpoint = '/api/v1/app/version';
  static const String _dismissedVersionKey = 'dismissed_update_version';
  
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
        final releaseNotes = data['releaseNotes'] as String?;
        final isRequired = data['isRequired'] as bool? ?? false;
        
        // Get platform-specific download URL
        String? downloadUrl;
        bool platformIsRequired = isRequired;
        
        // Check for new platforms structure
        if (data['platforms'] != null) {
          final platforms = data['platforms'] as Map<String, dynamic>;
          if (Platform.isWindows && platforms['windows'] != null) {
            final windowsInfo = platforms['windows'] as Map<String, dynamic>;
            downloadUrl = windowsInfo['downloadUrl'] as String?;
            platformIsRequired = windowsInfo['isRequired'] as bool? ?? isRequired;
          } else if (Platform.isAndroid && platforms['android'] != null) {
            final androidInfo = platforms['android'] as Map<String, dynamic>;
            downloadUrl = androidInfo['downloadUrl'] as String?;
            platformIsRequired = androidInfo['isRequired'] as bool? ?? isRequired;
          }
        } else {
          // Fallback to old structure for backward compatibility
          downloadUrl = data['downloadUrl'] as String?;
        }
        
        debugPrint('Latest version: $latestVersion+$latestBuildNumber');
        debugPrint('Platform: ${Platform.operatingSystem}');
        debugPrint('Download URL: $downloadUrl');
        debugPrint('Platforms data: ${data['platforms']}');
        
        // Compare versions
        if (_isNewerVersion(latestVersion, latestBuildNumber, currentVersion, currentBuildNumber)) {
          // Check if user has already dismissed this version
          final dismissedVersion = await _getDismissedVersion();
          final latestVersionString = '$latestVersion+$latestBuildNumber';
          
          // If this version was already dismissed, don't show it again
          if (dismissedVersion == latestVersionString) {
            debugPrint('Update $latestVersionString was already dismissed by user');
            return null;
          }
          
          if (downloadUrl == null || downloadUrl.isEmpty) {
            debugPrint('WARNING: Download URL is empty! Backend may not be deployed with latest version.');
            debugPrint('Platform-specific URL not found. Check backend deployment.');
          }
          return UpdateInfo(
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
            latestVersion: latestVersion,
            latestBuildNumber: latestBuildNumber,
            downloadUrl: downloadUrl ?? '',
            releaseNotes: releaseNotes ?? 'Bug fixes and improvements',
            isRequired: platformIsRequired,
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
  
  /// Mark a version as dismissed (user clicked "Later")
  static Future<void> dismissVersion(String version, int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedVersionKey, '$version+$buildNumber');
      debugPrint('Marked version $version+$buildNumber as dismissed');
    } catch (e) {
      debugPrint('Error saving dismissed version: $e');
    }
  }
  
  /// Get the last dismissed version
  static Future<String?> _getDismissedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_dismissedVersionKey);
    } catch (e) {
      debugPrint('Error reading dismissed version: $e');
      return null;
    }
  }
  
  /// Clear dismissed version (useful for testing or when a new version is released)
  static Future<void> clearDismissedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dismissedVersionKey);
      debugPrint('Cleared dismissed version');
    } catch (e) {
      debugPrint('Error clearing dismissed version: $e');
    }
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
      
      // For Android, use Downloads directory (more accessible)
      // For Windows, use system temp directory
      Directory downloadDir;
      if (Platform.isAndroid) {
        // Try to use Downloads directory
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate to Downloads folder
          final downloadsDir = Directory('${externalDir.path.replaceAll('/Android/data/com.example.central360/files', '')}/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          downloadDir = downloadsDir;
        } else {
          // Fallback to app's external files directory
          downloadDir = await getApplicationDocumentsDirectory();
        }
      } else {
        downloadDir = Directory.systemTemp;
      }
      
      final file = File('${downloadDir.path}/$fileName');
      
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
  
  /// Launch the installer/APK
  /// Windows: Launches the installer executable
  /// Android: Opens the APK file for installation
  static Future<void> installUpdate(String installerPath) async {
    try {
      if (Platform.isWindows) {
        // Launch installer - Windows will prompt for admin permission if needed
        // Using start command to open in a new window
        await Process.run(
          'cmd',
          ['/c', 'start', '', installerPath],
          runInShell: true,
        );
      } else if (Platform.isAndroid) {
        // For Android, try to open the APK file
        // The file should be in Downloads folder for easier access
        try {
          final file = File(installerPath);
          if (!await file.exists()) {
            throw Exception('APK file not found');
          }
          
          // Try using file:// URI first (works if file is in accessible location)
          final fileUri = Uri.file(installerPath);
          if (await canLaunchUrl(fileUri)) {
            await launchUrl(fileUri, mode: LaunchMode.externalApplication);
          } else {
            // Try content URI with FileProvider
            final packageName = 'com.example.central360';
            final fileName = installerPath.split('/').last;
            final contentUri = Uri.parse('content://$packageName.fileprovider/external_files/$fileName');
            if (await canLaunchUrl(contentUri)) {
              await launchUrl(contentUri, mode: LaunchMode.externalApplication);
            } else {
              // If both fail, provide clear instructions
              throw Exception('Please open Downloads folder and tap the APK file to install');
            }
          }
        } catch (e) {
          debugPrint('Error launching APK: $e');
          // Provide helpful error message with file location
          final fileName = installerPath.split('/').last;
          throw Exception('APK downloaded as: $fileName\nPlease open your Downloads folder and tap the file to install.');
        }
      } else {
        throw UnsupportedError('Auto-install not supported on ${Platform.operatingSystem}');
      }
    } catch (e) {
      debugPrint('Error launching installer: $e');
      // Try alternative method for Windows
      if (Platform.isWindows) {
        try {
          await Process.start(installerPath, [], mode: ProcessStartMode.detached);
        } catch (e2) {
          debugPrint('Alternative launch method also failed: $e2');
          rethrow;
        }
      } else {
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

