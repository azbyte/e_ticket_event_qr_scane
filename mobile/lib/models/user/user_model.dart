/// User account model (PRD sections 2 & 4.1).
///
/// Backend fields are placeholders pending the final API contract
/// (PRD section 15).
import 'user_role.dart';

class UserModel {
  final String? id;
  final String name;
  final String email;
  final UserRole role;
  final bool emailVerified;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;

  const UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.role,
    this.emailVerified = false,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  /// Creates a [UserModel] from JSON. Field names are tentative.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?) ?? UserRole.attendee,
      emailVerified: json['email_verified'] as bool? ?? false,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'email_verified': emailVerified,
      'phone': phone,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'UserModel(id: $id, email: $email, role: $role)';

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? emailVerified,
    String? phone,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      emailVerified: emailVerified ?? this.emailVerified,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
