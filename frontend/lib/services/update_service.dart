import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'dart:convert';
import '../config/env_config.dart';

class UpdateService {
  static const String _versionEndpoint = '/api/v1/app/version';
  static const String _dismissedVersionKey = 'dismissed_update_version';
  static const String _lastCheckTimeKey = 'last_update_check_time';
  static const Duration _checkCooldown = Duration(hours: 1); // Only check once per hour
  
  /// Check if a new version is available
  /// Returns [UpdateInfo] if update is available, null otherwise
  static Future<UpdateInfo?> checkForUpdate() async {
    // Check if we've checked recently (cooldown period)
    final lastCheckTime = await _getLastCheckTime();
    if (lastCheckTime != null) {
      final timeSinceLastCheck = DateTime.now().difference(lastCheckTime);
      if (timeSinceLastCheck < _checkCooldown) {
        debugPrint('Update check skipped - cooldown period active (${_checkCooldown.inMinutes - timeSinceLastCheck.inMinutes} minutes remaining)');
        return null;
      }
    }
    
    // Update last check time
    await _setLastCheckTime(DateTime.now());
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
        
        // Compare versions - only show update if there's actually a newer version
        final isNewer = _isNewerVersion(latestVersion, latestBuildNumber, currentVersion, currentBuildNumber);
        debugPrint('Version comparison: Latest=$latestVersion+$latestBuildNumber, Current=$currentVersion+$currentBuildNumber, IsNewer=$isNewer');
        
        if (isNewer) {
          // Check if user has already dismissed this version
          final dismissedVersion = await _getDismissedVersion();
          final latestVersionString = '$latestVersion+$latestBuildNumber';
          
          debugPrint('Dismissed version check: Stored=$dismissedVersion, Latest=$latestVersionString');
          
          // If this version was already dismissed, don't show it again
          if (dismissedVersion == latestVersionString) {
            debugPrint('Update $latestVersionString was already dismissed by user - skipping');
            return null;
          }
          
          if (downloadUrl == null || downloadUrl.isEmpty) {
            debugPrint('WARNING: Download URL is empty! Backend may not be deployed with latest version.');
            debugPrint('Platform-specific URL not found. Check backend deployment.');
          }
          
          debugPrint('Update available: $latestVersionString (current: $currentVersion+$currentBuildNumber)');
          return UpdateInfo(
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
            latestVersion: latestVersion,
            latestBuildNumber: latestBuildNumber,
            downloadUrl: downloadUrl ?? '',
            releaseNotes: releaseNotes ?? 'Bug fixes and improvements',
            isRequired: platformIsRequired,
          );
        } else {
          debugPrint('No update available - current version is up to date or newer');
          // Clear any dismissed version if we're on the latest version
          final dismissedVersion = await _getDismissedVersion();
          if (dismissedVersion != null) {
            debugPrint('Clearing dismissed version $dismissedVersion since we are on latest version');
            await clearDismissedVersion();
          }
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
      final versionString = '$version+$buildNumber';
      final success = await prefs.setString(_dismissedVersionKey, versionString);
      if (success) {
        debugPrint('✓ Successfully marked version $versionString as dismissed');
      } else {
        debugPrint('✗ Failed to save dismissed version $versionString');
      }
      
      // Verify it was saved
      final saved = prefs.getString(_dismissedVersionKey);
      debugPrint('Verification: Saved dismissed version = $saved');
    } catch (e) {
      debugPrint('Error saving dismissed version: $e');
    }
  }
  
  /// Get the last dismissed version
  static Future<String?> _getDismissedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getString(_dismissedVersionKey);
      debugPrint('Retrieved dismissed version from preferences: $dismissed');
      return dismissed;
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
  
  /// Get the last update check time
  static Future<DateTime?> _getLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastCheckTimeKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      debugPrint('Error reading last check time: $e');
      return null;
    }
  }
  
  /// Set the last update check time
  static Future<void> _setLastCheckTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckTimeKey, time.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving last check time: $e');
    }
  }
  
  /// Compare version strings and build numbers
  /// Returns true only if latest version is actually newer than current version
  static bool _isNewerVersion(
    String latestVersion,
    int latestBuildNumber,
    String currentVersion,
    int currentBuildNumber,
  ) {
    // If build numbers are different, use that as the primary comparison
    if (latestBuildNumber != currentBuildNumber) {
      return latestBuildNumber > currentBuildNumber;
    }
    
    // If build numbers are equal, compare version strings
    final latestParts = latestVersion.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final currentParts = currentVersion.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    
    // Compare each version part
    final maxLength = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    for (int i = 0; i < maxLength; i++) {
      final latest = i < latestParts.length ? latestParts[i] : 0;
      final current = i < currentParts.length ? currentParts[i] : 0;
      if (latest > current) return true;
      if (latest < current) return false;
    }
    
    // If all parts are equal, versions are the same - return false (no update needed)
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
        // Try to use Downloads directory - use getExternalStorageDirectory and navigate to Downloads
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Navigate to Downloads folder
            // Path format: /storage/emulated/0/Android/data/com.example.central360/files
            // We want: /storage/emulated/0/Download
            String downloadsPath;
            if (externalDir.path.contains('/Android/data/')) {
              // Extract the base storage path
              final basePath = externalDir.path.split('/Android/data/')[0];
              downloadsPath = '$basePath/Download';
            } else {
              // Fallback: try common Downloads paths
              downloadsPath = '/storage/emulated/0/Download';
            }
            
            final downloadsDir = Directory(downloadsPath);
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            downloadDir = downloadsDir;
            debugPrint('Using Downloads directory: $downloadsPath');
          } else {
            throw Exception('Could not access external storage');
          }
        } catch (e) {
          debugPrint('Error accessing Downloads directory: $e');
          // Fallback to app's external files directory
          downloadDir = await getApplicationDocumentsDirectory();
          debugPrint('Using fallback directory: ${downloadDir.path}');
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
        // For Android, use open_file package which properly handles APK installation
        try {
          final file = File(installerPath);
          if (!await file.exists()) {
            throw Exception('APK file not found at: $installerPath');
          }
          
          debugPrint('Opening APK file: $installerPath');
          
          // Use open_file package which properly handles APK installation on Android
          final result = await OpenFile.open(installerPath);
          
          debugPrint('OpenFile result: ${result.message}, type: ${result.type}');
          
          // Check if open_file succeeded (type 0 = done, other values indicate errors)
          if (result.type != 0) {
            // If open_file fails, try alternative method
            debugPrint('OpenFile failed with type: ${result.type}, message: ${result.message}');
            debugPrint('Trying alternative method...');
            
            // Try using content URI with FileProvider
            const packageName = 'com.example.central360';
            final fileName = installerPath.split('/').last;
            final contentUri = Uri.parse('content://$packageName.fileprovider/external_files/$fileName');
            
            if (await canLaunchUrl(contentUri)) {
              await launchUrl(contentUri, mode: LaunchMode.externalApplication);
            } else {
              // Last resort: provide clear instructions
              throw Exception('APK downloaded successfully.\n\nPlease:\n1. Open your file manager\n2. Navigate to Downloads folder\n3. Tap on $fileName to install');
            }
          }
        } catch (e) {
          debugPrint('Error launching APK: $e');
          // Provide helpful error message with file location
          final fileName = installerPath.split('/').last;
          throw Exception('APK downloaded as: $fileName\n\nPlease open your Downloads folder and tap the file to install.\n\nFile location: $installerPath');
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

