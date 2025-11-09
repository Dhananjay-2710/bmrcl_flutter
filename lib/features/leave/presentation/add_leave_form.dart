import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/leave_provider.dart';
import '../../../shared/utils/app_snackbar.dart';

class AddLeaveForm extends StatefulWidget {
  const AddLeaveForm({super.key});

  @override
  State<AddLeaveForm> createState() => _AddLeaveFormState();
}

class _AddLeaveFormState extends State<AddLeaveForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String _selectedLeaveType = 'Sick';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;
  bool _canSubmit = false;

  final List<String> _leaveTypes = [
    'Casual',
    'Sick',
    'Earned',
    'Unpaid',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(_updateSubmitState);
    _updateSubmitState();
  }

  @override
  void dispose() {
    _reasonController.removeListener(_updateSubmitState);
    _reasonController.dispose();
    super.dispose();
  }

  void _updateSubmitState() {
    final reason = _reasonController.text.trim();
    final reasonValid = reason.length >= 5;
    final startValid = _startDate != null;
    final endValid = _endDate != null;
    final rangeValid = startValid && endValid
        ? !_endDate!.isBefore(_startDate!)
        : false;

    final shouldEnable = reasonValid && rangeValid;
    if (shouldEnable != _canSubmit) {
      setState(() => _canSubmit = shouldEnable);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, reset it
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
      _updateSubmitState();
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      AppSnackBar.info(context, 'Please select start date first');
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _updateSubmitState();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      AppSnackBar.info(context, 'Please select both start and end dates');
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      AppSnackBar.error(context, 'End date cannot be before start date.');
      return;
    }

    if (!_canSubmit) {
      AppSnackBar.error(context, 'Please fill all required fields.');
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) {
      AppSnackBar.error(context, 'Not authenticated');
      return;
    }

    setState(() => _submitting = true);
    final prov = context.read<LeaveProvider>();

    try {
      final success = await prov.createLeave(
        token,
        leaveType: _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
      );

      if (!mounted) return;
      print("Submit leave: " + success.toString());
      if (success) {
        Navigator.pop(context, true);
        AppSnackBar.success(context, 'Leave request submitted successfully');
      } else {
        AppSnackBar.error(context, 'Failed: ${prov.error ?? "Unknown error"}');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Leave'),
        backgroundColor: const Color(0xFFA7D222),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Leave Type
              DropdownButtonFormField<String>(
                value: _selectedLeaveType,
                decoration: const InputDecoration(
                  labelText: 'Leave Type',
                  border: OutlineInputBorder(),
                ),
                items: _leaveTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedLeaveType = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Start Date
              InkWell(
                onTap: _selectStartDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _startDate == null
                        ? 'Select start date'
                        : DateFormat('dd/MM/yyyy').format(_startDate!),
                    style: TextStyle(
                      color: _startDate == null
                          ? Colors.grey[600]
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // End Date
              InkWell(
                onTap: _selectEndDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'End Date',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _endDate == null
                        ? 'Select end date'
                        : DateFormat('dd/MM/yyyy').format(_endDate!),
                    style: TextStyle(
                      color:
                          _endDate == null ? Colors.grey[600] : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Reason is required';
                  if (value.length < 5) {
                    return 'Reason must be at least 5 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (_submitting || !_canSubmit) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Leave Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
