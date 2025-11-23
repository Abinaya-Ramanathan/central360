import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee.dart';
import '../services/sector_service.dart';

class AddEmployeeDialog extends StatefulWidget {
  const AddEmployeeDialog({super.key});

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _contact2Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _bankDetailsController = TextEditingController();
  final _roleController = TextEditingController();
  final _dailySalaryController = TextEditingController();
  final _weeklySalaryController = TextEditingController();
  final _monthlySalaryController = TextEditingController();

  String? _selectedSector;
  DateTime? _joiningDate;
  int? _joiningYear;
  final SectorService _sectorService = SectorService();

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _contact2Controller.dispose();
    _addressController.dispose();
    _bankDetailsController.dispose();
    _roleController.dispose();
    _dailySalaryController.dispose();
    _weeklySalaryController.dispose();
    _monthlySalaryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _joiningDate = picked;
        _joiningYear = null; // Clear year if date is selected
      });
    }
  }

  Future<void> _selectYear() async {
    final int currentYear = DateTime.now().year;
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) {
        int selectedYear = currentYear;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Year'),
              content: SizedBox(
                width: 300,
                height: 200,
                child: YearPicker(
                  firstDate: DateTime(2000),
                  lastDate: DateTime(currentYear),
                  selectedDate: DateTime(selectedYear),
                  onChanged: (date) {
                    setState(() {
                      selectedYear = date.year;
                    });
                    Navigator.pop(context, selectedYear);
                  },
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() {
        _joiningYear = picked;
        _joiningDate = null; // Clear date if year is selected
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _selectedSector != null) {
      final employee = Employee(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        address: _addressController.text.trim(),
        bankDetails: _bankDetailsController.text.trim(),
        sector: _selectedSector!,
        role: _roleController.text.trim(),
        dailySalary: double.tryParse(_dailySalaryController.text) ?? 0.0,
        weeklySalary: double.tryParse(_weeklySalaryController.text) ?? 0.0,
        monthlySalary: double.tryParse(_monthlySalaryController.text) ?? 0.0,
        joiningDate: _joiningDate,
        joiningYear: _joiningYear,
      );
      Navigator.of(context).pop(employee);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields (Name, Contact, Sector)'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
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
                  const Icon(Icons.person_add, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add Employee',
                      style: TextStyle(
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name *',
                          prefixIcon: const Icon(Icons.person, color: Colors.blue),
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
                      const SizedBox(height: 16),
                      // Contact
                      TextFormField(
                        controller: _contactController,
                        decoration: InputDecoration(
                          labelText: 'Contact *',
                          prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      // Contact 2
                      TextFormField(
                        controller: _contact2Controller,
                        decoration: InputDecoration(
                          labelText: 'Contact 2',
                          prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          prefixIcon: const Icon(Icons.location_on, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      // Bank Details
                      TextFormField(
                        controller: _bankDetailsController,
                        decoration: InputDecoration(
                          labelText: 'Bank Details',
                          prefixIcon: const Icon(Icons.account_balance, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      // Sector Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSector,
                        decoration: InputDecoration(
                          labelText: 'Sector *',
                          prefixIcon: const Icon(Icons.business, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        items: _sectorService.sectors.map((sector) {
                          return DropdownMenuItem<String>(
                            value: sector.code,
                            child: Text('${sector.code} - ${sector.name}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSector = value;
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      // Role
                      TextFormField(
                        controller: _roleController,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          prefixIcon: const Icon(Icons.work, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Daily Salary
                      TextFormField(
                        controller: _dailySalaryController,
                        decoration: InputDecoration(
                          labelText: 'Daily Salary',
                          prefixIcon: const Icon(Icons.currency_rupee, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Weekly Salary
                      TextFormField(
                        controller: _weeklySalaryController,
                        decoration: InputDecoration(
                          labelText: 'Weekly Salary',
                          prefixIcon: const Icon(Icons.currency_rupee, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Monthly Salary
                      TextFormField(
                        controller: _monthlySalaryController,
                        decoration: InputDecoration(
                          labelText: 'Monthly Salary',
                          prefixIcon: const Icon(Icons.currency_rupee, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Joining Year & Date
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectYear,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Joining Year',
                                  prefixIcon: const Icon(Icons.calendar_month, color: Colors.blue),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                                  ),
                                ),
                                child: Text(
                                  _joiningYear == null
                                      ? 'Select Year'
                                      : _joiningYear.toString(),
                                  style: TextStyle(
                                    color: _joiningYear == null
                                        ? Colors.grey.shade600
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Joining Date (Optional)',
                                  prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                                  ),
                                ),
                                child: Text(
                                  _joiningDate == null
                                      ? 'Select Date'
                                      : '${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: _joiningDate == null
                                        ? Colors.grey.shade600
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                          child: const Text(
                            'Add Employee',
                            style: TextStyle(
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
            ),
          ],
        ),
      ),
    );
  }
}

