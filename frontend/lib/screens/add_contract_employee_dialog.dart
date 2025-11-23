import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contract_employee.dart';

class AddContractEmployeeDialog extends StatefulWidget {
  final ContractEmployee? contractEmployee;
  final DateTime selectedDate;

  const AddContractEmployeeDialog({
    super.key,
    this.contractEmployee,
    required this.selectedDate,
  });

  @override
  State<AddContractEmployeeDialog> createState() => _AddContractEmployeeDialogState();
}

class _AddContractEmployeeDialogState extends State<AddContractEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _membersCountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _salaryPerCountController = TextEditingController();
  final _totalSalaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.contractEmployee != null) {
      final ce = widget.contractEmployee!;
      _nameController.text = ce.name;
      _membersCountController.text = ce.membersCount.toString();
      _reasonController.text = ce.reason;
      _salaryPerCountController.text = ce.salaryPerCount.toString();
      _totalSalaryController.text = ce.totalSalary.toString();
    }
    // Calculate total salary when members count or salary per count changes
    _membersCountController.addListener(_calculateTotalSalary);
    _salaryPerCountController.addListener(_calculateTotalSalary);
  }

  void _calculateTotalSalary() {
    final membersCount = int.tryParse(_membersCountController.text) ?? 0;
    final salaryPerCount = double.tryParse(_salaryPerCountController.text) ?? 0.0;
    final totalSalary = membersCount * salaryPerCount;
    _totalSalaryController.text = totalSalary.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _membersCountController.dispose();
    _reasonController.dispose();
    _salaryPerCountController.dispose();
    _totalSalaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contractEmployee == null ? 'Add Contract Employee' : 'Edit Contract Employee'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _membersCountController,
                decoration: const InputDecoration(
                  labelText: 'Members Count *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  final count = int.tryParse(value);
                  if (count == null || count < 1) return 'Must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryPerCountController,
                decoration: const InputDecoration(
                  labelText: 'Salary Per Count *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  final salary = double.tryParse(value);
                  if (salary == null || salary < 0) return 'Must be 0 or greater';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalSalaryController,
                decoration: const InputDecoration(
                  labelText: 'Total Salary *',
                  border: OutlineInputBorder(),
                  enabled: false, // Auto-calculated
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final contractEmployee = {
                'name': _nameController.text.trim(),
                'members_count': int.parse(_membersCountController.text),
                'reason': _reasonController.text.trim(),
                'salary_per_count': double.parse(_salaryPerCountController.text),
                'total_salary': double.parse(_totalSalaryController.text),
                'date': widget.selectedDate.toIso8601String().split('T')[0],
              };
              Navigator.pop(context, contractEmployee);
            }
          },
          child: Text(widget.contractEmployee == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}

