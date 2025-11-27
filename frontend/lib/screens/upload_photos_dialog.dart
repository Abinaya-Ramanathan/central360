import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../config/env_config.dart';

class UploadPhotosDialog extends StatefulWidget {
  final int issueId;

  const UploadPhotosDialog({
    super.key,
    required this.issueId,
  });

  @override
  State<UploadPhotosDialog> createState() => _UploadPhotosDialogState();
}

class _UploadPhotosDialogState extends State<UploadPhotosDialog> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  List<String> _existingPhotos = [];
  bool _isLoading = false;
  bool _isLoadingPhotos = true;

  @override
  void initState() {
    super.initState();
    _loadExistingPhotos();
  }

  Future<void> _loadExistingPhotos() async {
    try {
      setState(() => _isLoadingPhotos = true);
      final photos = await ApiService.getMaintenanceIssuePhotos(widget.issueId);
      setState(() {
        _existingPhotos = photos.map((p) => p['image_url'] as String).toList();
        _isLoadingPhotos = false;
      });
    } catch (e) {
      setState(() => _isLoadingPhotos = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading photos: $e')),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      List<XFile> images = [];
      
      if (kIsWeb) {
        // For web, use file picker
        images = await _picker.pickMultiImage();
      } else if (Platform.isAndroid) {
        // For Android, use gallery
        images = await _picker.pickMultiImage();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop, use file picker
        images = await _picker.pickMultiImage();
      } else {
        // For iOS
        images = await _picker.pickMultiImage();
      }

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _uploadPhotos() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one photo')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Convert XFile to File
      List<File> files = [];
      for (var xFile in _selectedImages) {
        if (!kIsWeb) {
          files.add(File(xFile.path));
        } else {
          // For web, we need to handle differently
          // For now, skip web uploads or implement web-specific handling
          continue;
        }
      }

      if (files.isEmpty && !kIsWeb) {
        throw Exception('No valid files to upload');
      }

      await ApiService.uploadMaintenanceIssuePhotos(
        issueId: widget.issueId,
        photoFiles: files,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photos uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePhoto(String imageUrl) async {
    // Extract photo ID from the photos list
    try {
      final photos = await ApiService.getMaintenanceIssuePhotos(widget.issueId);
      final photo = photos.firstWhere((p) => p['image_url'] == imageUrl);
      final photoId = photo['id'] as int;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Photo'),
          content: const Text('Are you sure you want to delete this photo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await ApiService.deleteMaintenanceIssuePhoto(photoId);
      await _loadExistingPhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    // Images are served from the base URL, not the API endpoint
    return '${EnvConfig.apiBaseUrl}$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upload Photos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Existing photos
                    if (_isLoadingPhotos)
                      const Center(child: CircularProgressIndicator())
                    else if (_existingPhotos.isNotEmpty) ...[
                      const Text(
                        'Existing Photos:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _existingPhotos.length,
                        itemBuilder: (context, index) {
                          final imageUrl = _existingPhotos[index];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                _getImageUrl(imageUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.broken_image);
                                },
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deletePhoto(imageUrl),
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Selected new photos
                    if (_selectedImages.isNotEmpty) ...[
                      const Text(
                        'Selected Photos:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          final image = _selectedImages[index];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              kIsWeb
                                  ? Image.network(
                                      image.path,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(image.path),
                                      fit: BoxFit.cover,
                                    ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                  },
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Select Photos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading || _selectedImages.isEmpty ? null : _uploadPhotos,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

