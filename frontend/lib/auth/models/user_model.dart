class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? companyId;
  final int? departmentId;
  final int? locationId;
  final int? managerId;
  final int? departmentHeadId;
  final String? phone;
  final String? empCode;
  final String? username;
  final String? designation;
  final String? dateOfBirth;
  final bool isActive;
  final bool forcePasswordChange;
  final String? companyName;
  final String? departmentName;
  final String? locationName;
  final String? managerName;
  final String? departmentHeadName;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyId,
    this.departmentId,
    this.locationId,
    this.managerId,
    this.departmentHeadId,
    this.phone,
    this.empCode,
    this.username,
    this.designation,
    this.dateOfBirth,
    required this.isActive,
    required this.forcePasswordChange,
    this.companyName,
    this.departmentName,
    this.locationName,
    this.managerName,
    this.departmentHeadName,
  });

  String get fullName => name;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ??
        '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim();
    return UserModel(
      id: json['id'],
      name: name.isNotEmpty ? name : (json['email'] ?? 'User'),
      email: json['email'] ?? '',
      role: json['role'] ?? 'employee',
      companyId: json['company_id'],
      departmentId: json['department_id'],
      locationId: json['location_id'],
      managerId: json['manager_id'],
      departmentHeadId: json['department_head_id'],
      phone: json['phone'],
      empCode: json['emp_code'],
      username: json['username'],
      designation: json['designation'],
      dateOfBirth: json['date_of_birth'],
      isActive: json['is_active'] ?? true,
      forcePasswordChange: json['force_password_change'] ?? false,
      companyName: (json['company'] as Map<String, dynamic>?)?['name'],
      departmentName: (json['department'] as Map<String, dynamic>?)?['name'],
      locationName: (json['location'] as Map<String, dynamic>?)?['name'],
      managerName: (json['manager'] as Map<String, dynamic>?)?['name'],
      departmentHeadName:
          (json['department_head'] as Map<String, dynamic>?)?['name'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'company_id': companyId,
        'department_id': departmentId,
        'location_id': locationId,
        'manager_id': managerId,
        'department_head_id': departmentHeadId,
        'phone': phone,
        'emp_code': empCode,
        'username': username,
        'designation': designation,
        'date_of_birth': dateOfBirth,
        'is_active': isActive,
        'force_password_change': forcePasswordChange,
      };
}
