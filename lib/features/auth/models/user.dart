class User {
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final int? organizationId;
  final String? organizationName;
  final int? departmentId;
  final int? roleId;
  final String role;
  final String? status;
  final String? address;
  final int? cityId;
  final String? city;
  final int? stateId;
  final String? state;
  final int? countryId;
  final String? country;
  final String? postalCode;
  final String? profileImageUrl;
  final List<String> permissions;

  User({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.organizationId,
    this.organizationName,
    this.departmentId,
    this.roleId,
    this.status,
    this.address,
    this.cityId,
    this.city,
    this.stateId,
    this.state,
    this.countryId,
    this.country,
    this.postalCode,
    this.profileImageUrl,
    required this.permissions,
  });

  factory User.fromJson(Map<String, dynamic> j) {
    return User(
      userId: j['user_id'] ?? 0,
      name: j['name'] ?? '',
      email: j['email'] ?? '',
      phone: j['phone'],
      organizationId: j['organization_id'],
      organizationName: j['organization_name'],
      departmentId: j['department_id'],
      roleId: j['role_id'],
      role: j['role'],
      status: j['status'],
      address: j['address'],
      cityId: j['city_id'],
      city: j['city'],
      stateId: j['state_id'],
      state: j['state'],
      countryId: j['country_id'],
      country: j['country'],
      postalCode: j['postal_code'],
      profileImageUrl: j['profile_image_url'],
      permissions: List<String>.from(j['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'department_id': departmentId,
      'role_id': roleId,
      'role': role,
      'status': status,
      'address': address,
      'city_id': cityId,
      'city': city,
      'state_id': stateId,
      'state': state,
      'country_id': countryId,
      'country': country,
      'postal_code': postalCode,
      'profile_image_url': profileImageUrl,
      'permissions': permissions,
    };
  }

  @override
  String toString() {
    return 'User(name: $name, email: $email, role: $role)';
  }
}