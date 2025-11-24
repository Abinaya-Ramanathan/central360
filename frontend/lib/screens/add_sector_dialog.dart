import 'package:flutter/material.dart';
import '../models/sector.dart';
import '../services/api_service.dart';

class AddSectorDialog extends StatefulWidget {
  final Sector? existingSector;

  const AddSectorDialog({super.key, this.existingSector});

  @override
  State<AddSectorDialog> createState() => _AddSectorDialogState();
}

class _AddSectorDialogState extends State<AddSectorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingSector != null) {
      _codeController.text = widget.existingSector!.code;
      _nameController.text = widget.existingSector!.name;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final code = _codeController.text.trim().toUpperCase();
      final name = _nameController.text.trim();

      try {
        if (widget.existingSector != null) {
          // Update existing sector - Note: Sector code cannot be changed, only name
          // Since there's no update API, we'll show a message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sector code cannot be changed. Please delete and recreate if needed.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          // For now, we'll just close the dialog
          Navigator.of(context).pop();
        } else {
          final sector = Sector(code: code, name: name);
          final created = await ApiService.createSector(sector);
          Navigator.of(context).pop(created);
        }
      } catch (e) {
        // Extract error message - split main message from debug info
        String fullError = e.toString().replaceFirst('Exception: ', '');
        String errorMessage = fullError;
        String debugInfo = '';
        
        // Check if there's debug info in the error
        if (fullError.contains('\n\n[Debug:')) {
          final parts = fullError.split('\n\n[Debug:');
          errorMessage = parts[0].trim();
          if (parts.length > 1) {
            debugInfo = parts[1].replaceFirst(']', '').trim();
          }
        }
        
        // Log full error details for debugging
        debugPrint('=== SECTOR CREATION ERROR ===');
        debugPrint('Full error: $e');
        debugPrint('Error message: $errorMessage');
        debugPrint('Debug info: $debugInfo');
        debugPrint('Sector code: ${_codeController.text}');
        debugPrint('Sector name: ${_nameController.text}');
        debugPrint('============================');
        
        // Show more detailed error in a dialog for better visibility
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error Creating Sector', style: TextStyle(color: Colors.red)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorMessage,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (debugInfo.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Technical Details:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        debugInfo,
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Sector Details:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${_codeController.text}\nName: ${_nameController.text}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        
        // Also show snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_business, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.existingSector != null ? 'Edit Sector' : 'Add Sector',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Form
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sector Code
                    TextFormField(
                      controller: _codeController,
                      enabled: widget.existingSector == null, // Disable if editing
                      decoration: InputDecoration(
                        labelText: 'Sector Code *',
                        hintText: 'e.g., SSBM, SSC',
                        prefixIcon: const Icon(Icons.code, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Sector Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Sector Name *',
                        hintText: 'e.g., SRI SURYA BLUE METALS',
                        prefixIcon: const Icon(Icons.business, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.existingSector != null ? 'Update Sector' : 'Add Sector',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

