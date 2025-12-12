import 'package:flutter/material.dart';
import '../models/mahal_booking.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';

class AddMahalBookingDialog extends StatefulWidget {
  final String selectedSector;
  final MahalBooking? booking;

  const AddMahalBookingDialog({
    super.key,
    required this.selectedSector,
    this.booking,
  });

  @override
  State<AddMahalBookingDialog> createState() => _AddMahalBookingDialogState();
}

class _AddMahalBookingDialogState extends State<AddMahalBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientPhone1Controller = TextEditingController();
  final _clientPhone2Controller = TextEditingController();
  final _clientAddressController = TextEditingController();
  final _eventTimingController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _detailsController = TextEditingController();
  final _finalSettlementAmountController = TextEditingController();

  String? _selectedMahalDetail;
  String? _selectedFoodService;
  String? _selectedOrderStatus;
  DateTime? _eventDate;
  bool _isSubmitting = false;

  final List<String> _mahalDetails = [
    'Thanthondrimalai Mini hall',
    'Thirukampuliyur Minihall',
    'Thirukampuliyur Big Hall',
    'Only Catering Orders',
  ];

  final List<String> _foodServices = ['Internal', 'External'];
  final List<String> _orderStatuses = ['open', 'closed'];

  @override
  void initState() {
    super.initState();
    if (widget.booking != null) {
      _selectedMahalDetail = widget.booking!.mahalDetail;
      _selectedFoodService = widget.booking!.foodService;
      _eventDate = widget.booking!.eventDate;
      _eventDateController.text = FormatUtils.formatDateDisplay(_eventDate);
      _eventNameController.text = widget.booking!.eventName ?? '';
      _eventTimingController.text = widget.booking!.eventTiming ?? '';
      _clientNameController.text = widget.booking!.clientName;
      _clientPhone1Controller.text = widget.booking!.clientPhone1 ?? '';
      _clientPhone2Controller.text = widget.booking!.clientPhone2 ?? '';
      _clientAddressController.text = widget.booking!.clientAddress ?? '';
      _selectedOrderStatus = widget.booking!.orderStatus ?? 'open';
      _detailsController.text = widget.booking!.details ?? '';
      _finalSettlementAmountController.text = widget.booking!.finalSettlementAmount?.toStringAsFixed(2) ?? '';
    } else {
      _selectedOrderStatus = 'open';
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _clientNameController.dispose();
    _clientPhone1Controller.dispose();
    _clientPhone2Controller.dispose();
    _clientAddressController.dispose();
    _eventTimingController.dispose();
    _eventDateController.dispose();
    _detailsController.dispose();
    _finalSettlementAmountController.dispose();
    super.dispose();
  }

  void _onEventDateTextChanged(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _eventDate = null;
      });
      return;
    }
    final parsedDate = FormatUtils.parseDate(value);
    if (parsedDate != null) {
      setState(() {
        _eventDate = parsedDate;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMahalDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a mahal detail'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Parse date from text field if not already set
    if (_eventDate == null && _eventDateController.text.trim().isNotEmpty) {
      _eventDate = FormatUtils.parseDate(_eventDateController.text);
    }

    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid event date in DD/MM/YYYY format'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Generate booking_id: client_name + event_date
      final clientName = _clientNameController.text.trim();
      final cleanClientName = clientName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final bookingId = widget.booking?.bookingId ?? 
          '${cleanClientName}_${_eventDate!.toIso8601String().split('T')[0]}';

      final booking = MahalBooking(
        bookingId: widget.booking?.bookingId ?? bookingId,
        sectorCode: widget.selectedSector,
        mahalDetail: _selectedMahalDetail!,
        eventDate: _eventDate!,
        eventTiming: _eventTimingController.text.trim().isEmpty
            ? null
            : _eventTimingController.text.trim(),
        eventName: _eventNameController.text.trim().isEmpty
            ? null
            : _eventNameController.text.trim(),
        clientName: clientName,
        clientPhone1: _clientPhone1Controller.text.trim().isEmpty
            ? null
            : _clientPhone1Controller.text.trim(),
        clientPhone2: _clientPhone2Controller.text.trim().isEmpty
            ? null
            : _clientPhone2Controller.text.trim(),
        clientAddress: _clientAddressController.text.trim().isEmpty
            ? null
            : _clientAddressController.text.trim(),
        foodService: _selectedFoodService,
        orderStatus: _selectedOrderStatus,
        details: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
        finalSettlementAmount: _finalSettlementAmountController.text.trim().isEmpty
            ? null
            : double.tryParse(_finalSettlementAmountController.text.trim()),
      );

      if (widget.booking != null) {
        await ApiService.updateMahalBooking(booking);
      } else {
        await ApiService.createMahalBooking(booking);
      }

      if (mounted) {
        Navigator.of(context).pop(booking);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.booking != null
                ? 'Event details updated successfully'
                : 'Event details added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 900),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.booking != null ? 'Edit Event Details' : 'Add Event Details',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Mahal Detail Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedMahalDetail,
                  decoration: InputDecoration(
                    labelText: 'Mahal Detail *',
                    prefixIcon: const Icon(Icons.location_city, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  items: _mahalDetails.map((detail) {
                    return DropdownMenuItem<String>(
                      value: detail,
                      child: Text(detail),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMahalDetail = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a mahal detail';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Event Date
                TextFormField(
                  controller: _eventDateController,
                  decoration: InputDecoration(
                    labelText: 'Event Date *',
                    hintText: 'DD/MM/YYYY',
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  onChanged: _onEventDateTextChanged,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Event date is required';
                    }
                    final parsedDate = FormatUtils.parseDate(value);
                    if (parsedDate == null) {
                      return 'Invalid format. Use DD/MM/YYYY';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Event Timing
                TextFormField(
                  controller: _eventTimingController,
                  decoration: InputDecoration(
                    labelText: 'Event Timing',
                    hintText: 'e.g., 10:00 AM - 2:00 PM',
                    prefixIcon: const Icon(Icons.access_time, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Event Name
                TextFormField(
                  controller: _eventNameController,
                  decoration: InputDecoration(
                    labelText: 'Event Name',
                    hintText: 'e.g., Wedding Reception',
                    prefixIcon: const Icon(Icons.event, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Client Name
                TextFormField(
                  controller: _clientNameController,
                  decoration: InputDecoration(
                    labelText: 'Client Name *',
                    hintText: 'Enter client name',
                    prefixIcon: const Icon(Icons.person, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Client name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Client Phone 1
                TextFormField(
                  controller: _clientPhone1Controller,
                  decoration: InputDecoration(
                    labelText: 'Client Phone Number 1',
                    hintText: 'Enter phone number',
                    prefixIcon: const Icon(Icons.phone, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                // Client Phone 2
                TextFormField(
                  controller: _clientPhone2Controller,
                  decoration: InputDecoration(
                    labelText: 'Client Phone Number 2',
                    hintText: 'Enter phone number',
                    prefixIcon: const Icon(Icons.phone, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                // Client Address
                TextFormField(
                  controller: _clientAddressController,
                  decoration: InputDecoration(
                    labelText: 'Client Address',
                    hintText: 'Enter client address',
                    prefixIcon: const Icon(Icons.location_on, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Food Service Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedFoodService,
                  decoration: InputDecoration(
                    labelText: 'Food Service',
                    prefixIcon: const Icon(Icons.restaurant, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  items: _foodServices.map((service) {
                    return DropdownMenuItem<String>(
                      value: service,
                      child: Text(service),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFoodService = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Details
                TextFormField(
                  controller: _detailsController,
                  decoration: InputDecoration(
                    labelText: 'Details',
                    hintText: 'Enter additional details',
                    prefixIcon: const Icon(Icons.note, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Order Status Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedOrderStatus,
                  decoration: InputDecoration(
                    labelText: 'Settlement Status',
                    prefixIcon: const Icon(Icons.assignment, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  items: _orderStatuses.map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOrderStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Final Settlement Amount
                TextFormField(
                  controller: _finalSettlementAmountController,
                  decoration: InputDecoration(
                    labelText: 'Final Settlement Amount',
                    hintText: 'Enter final settlement amount',
                    prefixIcon: const Icon(Icons.currency_rupee, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final amount = double.tryParse(value.trim());
                      if (amount == null) {
                        return 'Please enter a valid amount';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                      label: Text(
                        _isSubmitting
                            ? (widget.booking != null ? 'Updating...' : 'Adding...')
                            : (widget.booking != null ? 'Update Event' : 'Add Event'),
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

