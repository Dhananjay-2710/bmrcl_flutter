import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../constants/api_constants.dart';
import '../../../providers/imagepicker_provider.dart';
import '../../../shared/utils/app_snackbar.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final User user;
  const ProfileDetailsScreen({super.key, required this.user});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  static const Color _brand = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);
  static const Color _bg = Color(0xFFFDF6E9);

  bool _isEditing = false;
  bool _saving = false;
  User? _currentUser;
  File? _selectedImage;
  int _avatarVersion = 0;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  String _initialName = '';
  String _initialPhone = '';
  String _initialAddress = '';
  bool _canSubmit = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
    _captureInitialValues();
    _nameController.addListener(_updateSubmitState);
    _phoneController.addListener(_updateSubmitState);
    _addressController.addListener(_updateSubmitState);
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateSubmitState);
    _phoneController.removeListener(_updateSubmitState);
    _addressController.removeListener(_updateSubmitState);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _captureInitialValues() {
    _initialName = _nameController.text.trim();
    _initialPhone = _phoneController.text.trim();
    _initialAddress = _addressController.text.trim();
    _updateSubmitState();
  }

  void _updateSubmitState() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    final nameValid = name.length >= 3;
    final phoneValid = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone);
    final addressValid = address.length >= 5;
    final isValid = nameValid && phoneValid && addressValid;
    final imageChanged = _selectedImage != null;

    final changed = name != _initialName ||
        phone != _initialPhone ||
        address != _initialAddress ||
        imageChanged;
    final shouldEnable = _isEditing && isValid && changed;

    if (_canSubmit != shouldEnable || _hasChanges != changed) {
      setState(() {
        _canSubmit = shouldEnable;
        _hasChanges = changed;
      });
    }
  }

  ImageProvider _avatarProvider() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }
    final url = _currentUser?.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      final cacheBusted = _avatarVersion == 0
          ? url
          : '$url${url.contains('?') ? '&' : '?'}v=$_avatarVersion';
      return NetworkImage(cacheBusted);
    }
    return const AssetImage('assets/images/profile.jpg');
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  void _toast(String msg, {bool success = false}) {
    if (success) {
      AppSnackBar.success(context, msg);
    } else {
      AppSnackBar.error(context, msg);
    }
  }

  String _pickString(Map<String, dynamic> map, String key, String fallback) {
    final value = map[key];
    if (value == null) return fallback;
    final str = value.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  String? _pickNullableString(Map<String, dynamic> map, String key, String? fallback) {
    final value = map[key];
    if (value == null) return fallback;
    final str = value.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  int? _pickNullableInt(Map<String, dynamic> map, String key, int? fallback) {
    final value = map[key];
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }

  User _mergeUser(User base, Map<String, dynamic> data) {
    final inputName = _nameController.text.trim();
    final inputEmail = _emailController.text.trim();
    final inputPhone = _phoneController.text.trim();
    final inputAddress = _addressController.text.trim();

    return User(
      userId: _pickNullableInt(data, 'user_id', base.userId) ?? base.userId,
      name: _pickString(data, 'name', inputName.isNotEmpty ? inputName : base.name),
      email: _pickString(data, 'email', inputEmail.isNotEmpty ? inputEmail : base.email),
      role: _pickString(data, 'role', base.role),
      phone: _pickNullableString(
        data,
        'phone',
        inputPhone.isNotEmpty ? inputPhone : base.phone,
      ),
      organizationId: _pickNullableInt(data, 'organization_id', base.organizationId),
      organizationName: _pickNullableString(data, 'organization_name', base.organizationName),
      departmentId: _pickNullableInt(data, 'department_id', base.departmentId),
      roleId: _pickNullableInt(data, 'role_id', base.roleId),
      status: _pickNullableString(data, 'status', base.status),
      address: _pickNullableString(
        data,
        'address',
        inputAddress.isNotEmpty ? inputAddress : base.address,
      ),
      cityId: _pickNullableInt(data, 'city_id', base.cityId),
      city: _pickNullableString(data, 'city', base.city),
      stateId: _pickNullableInt(data, 'state_id', base.stateId),
      state: _pickNullableString(data, 'state', base.state),
      countryId: _pickNullableInt(data, 'country_id', base.countryId),
      country: _pickNullableString(data, 'country', base.country),
      postalCode: _pickNullableString(data, 'postal_code', base.postalCode),
      profileImageUrl: _pickNullableString(data, 'profile_image_url', base.profileImageUrl),
      permissions: base.permissions,
    );
  }

  Future<void> _pickProfileImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final picker = context.read<ImagePickerProvider>();
    final file = await picker.pickCompressedImage(source: source);
    if (file != null && mounted) {
      setState(() {
        _selectedImage = file;
      });
      _updateSubmitState();
    }
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    final user = _currentUser;

    if (token == null || user == null) {
      _toast('Not authenticated.');
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || name.length < 3) {
      _toast('Please enter a valid name (minimum 3 characters).');
      return;
    }

    final phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
    if (phone.isEmpty || !phonePattern.hasMatch(phone)) {
      _toast('Please enter a valid phone number (7-15 digits, optional +).');
      return;
    }

    if (address.isEmpty || address.length < 5) {
      _toast('Please enter a valid address (minimum 5 characters).');
      return;
    }

    if (!_hasChanges) {
      _toast('No changes to update.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userUpdateEndpoint(user.userId)}');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['name'] = _nameController.text.trim()
        ..fields['email'] = _emailController.text.trim()
        ..fields['phone'] = _phoneController.text.trim()
        ..fields['address'] = _addressController.text.trim();

      if (user.cityId != null) {
        request.fields['city_id'] = user.cityId.toString();
      }
      if (user.stateId != null) {
        request.fields['state_id'] = user.stateId.toString();
      }
      if (user.countryId != null) {
        request.fields['country_id'] = user.countryId.toString();
      }
      if (user.postalCode != null && user.postalCode!.isNotEmpty) {
        request.fields['postal_code'] = user.postalCode!;
      }

      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('profile_image', _selectedImage!.path));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body = responseBody.isNotEmpty
            ? jsonDecode(responseBody) as Map<String, dynamic>
            : {};
        final dynamic payload = body['user'] ?? body['data'] ?? body['profile'] ?? body;
        if (payload is! Map<String, dynamic>) {
          throw const FormatException('Unexpected response format');
        }

        final mergedUser = _mergeUser(user, Map<String, dynamic>.from(payload));
        User finalUser = mergedUser;

        try {
          final profileResponse = await auth.auth.getProfile(token);
          final dynamic profilePayload =
              profileResponse['user'] ?? profileResponse['data'] ?? profileResponse;
          if (profilePayload is Map<String, dynamic>) {
            finalUser = _mergeUser(mergedUser, Map<String, dynamic>.from(profilePayload));
          }
        } catch (_) {
          finalUser = mergedUser;
        }

        if (!mounted) return;
        setState(() {
          _currentUser = finalUser;
          _isEditing = false;
          _saving = false;
          if (_selectedImage != null) {
            _avatarVersion++;
          }
          _selectedImage = null;
          _nameController.text = finalUser.name;
          _emailController.text = finalUser.email;
          _phoneController.text = finalUser.phone ?? '';
          _addressController.text = finalUser.address ?? '';
          _captureInitialValues();
        });

        await auth.updateLocalUser(finalUser);
        _toast(
          body['message']?.toString() ?? 'Profile updated successfully ✅',
          success: true,
        );
      } else {
        String errorMessage = 'Failed to update profile (HTTP ${response.statusCode})';
        try {
          final Map<String, dynamic> errorBody = responseBody.isNotEmpty
              ? jsonDecode(responseBody) as Map<String, dynamic>
              : {};
          errorMessage = errorBody['message']?.toString() ?? errorMessage;
        } catch (_) {
          errorMessage = responseBody.isNotEmpty ? responseBody : errorMessage;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _captureInitialValues();
                });
              },
              tooltip: 'Edit Profile',
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset to original values
                  if (_selectedImage != null) {
                    _avatarVersion++;
                  }
                  _selectedImage = null;
                  _nameController.text = user.name;
                  _emailController.text = user.email;
                  _phoneController.text = user.phone ?? '';
                  _addressController.text = user.address ?? '';
                  _captureInitialValues();
                });
              },
              tooltip: 'Cancel',
            ),
        ],
      ),
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ProfileSummaryCard(
                user: user,
                isEditing: _isEditing,
                nameController: _nameController,
                avatarProvider: _avatarProvider,
                initialsBuilder: _initials,
                onPickImage: _pickProfileImage,
                hasPendingImage: _selectedImage != null,
              ),

              const SizedBox(height: 16),

              _ProfileInfoCard(
                user: user,
                isEditing: _isEditing,
                emailController: _emailController,
                phoneController: _phoneController,
                addressController: _addressController,
              ),

              if (_isEditing) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: (_saving || !_canSubmit) ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, color: Colors.white),
                    label: Text(
                      _saving ? 'Saving…' : 'Save Changes',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandDark,
                      disabledBackgroundColor: _brandDark.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final User user;
  final bool isEditing;
  final TextEditingController nameController;
  final ImageProvider Function() avatarProvider;
  final String Function(String) initialsBuilder;
  final VoidCallback onPickImage;
  final bool hasPendingImage;

  const _ProfileSummaryCard({
    required this.user,
    required this.isEditing,
    required this.nameController,
    required this.avatarProvider,
    required this.initialsBuilder,
    required this.onPickImage,
    required this.hasPendingImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      user.city?.trim(),
      user.state?.trim(),
      user.country?.trim(),
    ].whereType<String>().where((value) => value.isNotEmpty).join(', ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: avatarProvider(),
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                    ),
                    if ((user.profileImageUrl == null || user.profileImageUrl!.isEmpty) && !hasPendingImage)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Text(
                              initialsBuilder(user.name),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (isEditing)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: InkWell(
                          onTap: onPickImage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isEditing)
                        Text(
                          user.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: Icons.badge_outlined,
                            label: user.role,
                            background: const Color(0xFFE8F4D8),
                            color: const Color(0xFF466100),
                          ),
                          if ((user.organizationName ?? '').isNotEmpty)
                            _InfoChip(
                              icon: Icons.business_outlined,
                              label: user.organizationName!,
                              background: const Color(0xFFE8F0FF),
                              color: const Color(0xFF1E429F),
                            ),
                          if (location.isNotEmpty)
                            _InfoChip(
                              icon: Icons.location_on_outlined,
                              label: location,
                              background: const Color(0xFFFFF2E0),
                              color: const Color(0xFF8C5300),
                            ),
                        ],
                      ),
                    ],
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

class _ProfileInfoCard extends StatelessWidget {
  final User user;
  final bool isEditing;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;

  const _ProfileInfoCard({
    required this.user,
    required this.isEditing,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      user.city?.trim(),
      user.state?.trim(),
      user.country?.trim(),
    ].whereType<String>().where((value) => value.isNotEmpty).join(', ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Personal Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailField(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user.email,
              isEditing: isEditing,
              controller: emailController,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _DetailField(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phone ?? 'Not provided',
              isEditing: isEditing,
              controller: phoneController,
            ),
            const SizedBox(height: 16),
            _DetailField(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: user.address ?? 'Not provided',
              isEditing: isEditing,
              controller: addressController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _DetailField(
              icon: Icons.verified_user_outlined,
              label: 'Role',
              value: user.role,
              isEditing: false,
            ),
            if ((user.organizationName ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailField(
                icon: Icons.business_outlined,
                label: 'Organization',
                value: user.organizationName!,
                isEditing: false,
              ),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailField(
                icon: Icons.location_city_outlined,
                label: 'Location',
                value: location,
                isEditing: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isEditing;
  final TextEditingController? controller;
  final bool readOnly;
  final int maxLines;

  const _DetailField({
    required this.icon,
    required this.label,
    required this.value,
    this.isEditing = false,
    this.controller,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isEditing && controller != null && !readOnly) {
      return TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

