import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';

class AddMiningActivityDialog extends StatefulWidget {
  final String? preSelectedSector;

  const AddMiningActivityDialog({super.key, this.preSelectedSector});

  @override
  State<AddMiningActivityDialog> createState() => _AddMiningActivityDialogState();
}

class _AddMiningActivityDialogState extends State<AddMiningActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _activityNameControllers = [TextEditingController()];
  final List<TextEditingController> _descriptionControllers = [TextEditingController()];
  String? _selectedSectorCode;
  List<Sector> _sectors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSectorCode = widget.preSelectedSector;
    _loadSectors();
  }

  Future<void> _loadSectors() async {
    try {
      final sectors = await ApiService.getSectors();
      setState(() {
        _sectors = sectors;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sectors: $e')),
        );
      }
    }
  }

  void _addActivityRow() {
    setState(() {
      _activityNameControllers.add(TextEditingController());
      _descriptionControllers.add(TextEditingController());
    });
  }

  void _removeActivityRow(int index) {
    if (_activityNameControllers.length > 1) {
      setState(() {
        _activityNameControllers[index].dispose();
        _descriptionControllers[index].dispose();
        _activityNameControllers.removeAt(index);
        _descriptionControllers.removeAt(index);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSectorCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sector')),
      );
      return;
    }

    // Validate that at least one activity name is filled
    bool hasAtLeastOneActivity = false;
    for (var controller in _activityNameControllers) {
      if (controller.text.trim().isNotEmpty) {
        hasAtLeastOneActivity = true;
        break;
      }
    }

    if (!hasAtLeastOneActivity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one activity name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    int successCount = 0;
    int errorCount = 0;
    List<String> errorMessages = [];

    try {
      for (int i = 0; i < _activityNameControllers.length; i++) {
        final activityName = _activityNameControllers[i].text.trim();
        if (activityName.isEmpty) continue; // Skip empty activities

        try {
          await ApiService.createMiningActivity(
            activityName,
            _selectedSectorCode!,
            description: _descriptionControllers[i].text.trim().isEmpty 
                ? null 
                : _descriptionControllers[i].text.trim(),
          );
          successCount++;
        } catch (e) {
          errorCount++;
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          errorMessages.add('$activityName: $errorMessage');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        String message;
        if (errorCount == 0) {
          message = '$successCount mining activity(ies) created successfully';
        } else {
          message = '$successCount activity(ies) created, $errorCount failed. ${errorMessages.join("; ")}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: errorCount > 0 ? 6 : 2),
            backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _activityNameControllers) {
      controller.dispose();
    }
    for (var controller in _descriptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.construction, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          const Text('Add Mining Activity'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sector Dropdown (shared for all activities)
              DropdownButtonFormField<String>(
                initialValue: _selectedSectorCode,
                decoration: InputDecoration(
                  labelText: 'Sector * (applies to all activities)',
                  prefixIcon: const Icon(Icons.business, color: Colors.amber),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber, width: 2),
                  ),
                ),
                hint: const Text('Select Sector'),
                items: _sectors.map((sector) {
                  return DropdownMenuItem<String>(
                    value: sector.code,
                    child: Text('${sector.code} - ${sector.name}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSectorCode = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a sector';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Activities List
              ...List.generate(_activityNameControllers.length, (index) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Activity ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ),
                        if (_activityNameControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeActivityRow(index),
                            tooltip: 'Remove this activity',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Activity Name
                    TextFormField(
                      controller: _activityNameControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Activity Name *',
                        hintText: 'e.g., Excavation, Loading, etc.',
                        prefixIcon: const Icon(Icons.construction, color: Colors.amber),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.amber, width: 2),
                        ),
                      ),
                      validator: (value) {
                        // Only validate if other activities have values or this is the first activity
                        bool hasOtherActivities = false;
                        for (int i = 0; i < _activityNameControllers.length; i++) {
                          if (i != index && _activityNameControllers[i].text.trim().isNotEmpty) {
                            hasOtherActivities = true;
                            break;
                          }
                        }
                        if (hasOtherActivities && (value == null || value.trim().isEmpty)) {
                          return 'Activity name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Description
                    TextFormField(
                      controller: _descriptionControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional description',
                        prefixIcon: const Icon(Icons.description, color: Colors.amber),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.amber, width: 2),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    if (index < _activityNameControllers.length - 1) const SizedBox(height: 16),
                  ],
                );
              }),
              const SizedBox(height: 16),
              // Add More Activities Button
              OutlinedButton.icon(
                onPressed: _addActivityRow,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Activity'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber.shade700,
                  side: BorderSide(color: Colors.amber.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

