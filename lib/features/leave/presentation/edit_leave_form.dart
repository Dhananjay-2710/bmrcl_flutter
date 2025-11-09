import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/leave_provider.dart';
import '../models/leave.dart';
import '../../../shared/utils/app_snackbar.dart';

class EditLeaveForm extends StatefulWidget {
  final Leave leave;

  const EditLeaveForm({super.key, required this.leave});

  @override
  State<EditLeaveForm> createState() => _EditLeaveFormState();
}

class _EditLeaveFormState extends State<EditLeaveForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late String _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;
  bool _canSubmit = false;
  bool _hasChanges = false;
  late String _initialLeaveType;
  DateTime? _initialStartDate;
  DateTime? _initialEndDate;
  late String _initialReason;

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
    _selectedLeaveType = widget.leave.leaveType ?? 'Sick';
    _startDate = widget.leave.startDate;
    _endDate = widget.leave.endDate;
    _reasonController.text = widget.leave.reason ?? '';
    _captureInitialValues();
    _reasonController.addListener(_updateSubmitState);
    _updateSubmitState();
  }

  @override
  void dispose() {
    _reasonController.removeListener(_updateSubmitState);
    _reasonController.dispose();
    super.dispose();
  }

  void _captureInitialValues() {
    _initialLeaveType = _selectedLeaveType;
    _initialStartDate = _startDate;
    _initialEndDate = _endDate;
    _initialReason = _reasonController.text.trim();
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _updateSubmitState() {
    final reason = _reasonController.text.trim();
    final reasonValid = reason.length >= 5;
    final startValid = _startDate != null;
    final endValid = _endDate != null;
    final rangeValid = startValid && endValid
        ? !_endDate!.isBefore(_startDate!)
        : false;

    final changed = (_selectedLeaveType != _initialLeaveType) ||
        !_isSameDate(_startDate, _initialStartDate) ||
        !_isSameDate(_endDate, _initialEndDate) ||
        (reason != _initialReason);

    final shouldEnable = reasonValid && rangeValid && changed;

    if (shouldEnable != _canSubmit || changed != _hasChanges) {
      setState(() {
        _canSubmit = shouldEnable;
        _hasChanges = changed;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
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
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
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

    if (!_hasChanges) {
      AppSnackBar.error(context, 'No changes to update');
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
      final success = await prov.updateLeave(
        token,
        widget.leave.id,
        leaveType: _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
        AppSnackBar.success(context, 'Leave request updated successfully ✅');
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
        title: const Text('Edit Leave Request'),
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
                    _updateSubmitState();
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
                          'Update Leave Request',
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
