import 'package:flutter/material.dart';
import 'dart:io';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  
  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.updateInfo.isRequired && !_isDownloading,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: widget.updateInfo.isRequired ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 8),
            const Text('Update Available'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.updateInfo.isRequired
                    ? 'A required update is available. Please update to continue using the app.'
                    : 'A new version of Company360 is available!',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildVersionInfo(),
              const SizedBox(height: 16),
              if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
                const Text(
                  'What\'s New:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.updateInfo.releaseNotes,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text(
                  'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (_isInstalling) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Preparing installer...'),
                  ],
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.updateInfo.isRequired && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
          if (!_isDownloading && !_isInstalling)
            FilledButton(
              onPressed: _downloadAndInstall,
              child: const Text('Update Now'),
            )
          else if (_isDownloading)
            const FilledButton(
              onPressed: null,
              child: Text('Downloading...'),
            )
          else
            const FilledButton(
              onPressed: null,
              child: Text('Installing...'),
            ),
        ],
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Current Version: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${widget.updateInfo.currentVersion}+${widget.updateInfo.currentBuildNumber}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Latest Version: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                widget.updateInfo.versionString,
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall() async {
    if (widget.updateInfo.downloadUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Download URL not available. Please download manually from the website.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    try {
      // Download the update
      final installerPath = await UpdateService.downloadUpdate(
        widget.updateInfo.downloadUrl,
        (downloaded, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = total > 0 ? downloaded / total : 0.0;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _isInstalling = true;
      });

      // Launch installer/APK based on platform
      if (Platform.isWindows || Platform.isAndroid) {
        await UpdateService.installUpdate(installerPath!);
        
        if (mounted) {
          Navigator.of(context).pop(true);
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Platform.isWindows
                    ? 'Update installer launched. Please follow the installation prompts.'
                    : 'APK file opened. Please follow the installation prompts.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // For other platforms, just open the file
        setState(() {
          _errorMessage = 'Please install the update manually from: $installerPath';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
          _errorMessage = 'Failed to download update: $e';
        });
      }
    }
  }
}

