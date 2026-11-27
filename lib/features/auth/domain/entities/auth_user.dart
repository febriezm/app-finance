/// Entity AuthUser mewakili pengguna terautentikasi pada MyFinance
class AuthUser {
  final String id;
  final String email;
  final String? name;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? emailConfirmedAt;
  final Map<String, dynamic>? userMetadata;

  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.createdAt,
    this.emailConfirmedAt,
    this.userMetadata,
  });

  bool get isEmailConfirmed => emailConfirmedAt != null;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : email;

  AuthUser copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    DateTime? createdAt,
    DateTime? emailConfirmedAt,
    Map<String, dynamic>? userMetadata,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      emailConfirmedAt: emailConfirmedAt ?? this.emailConfirmedAt,
      userMetadata: userMetadata ?? this.userMetadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          name == other.name &&
          phone == other.phone;

  @override
  int get hashCode =>
      id.hashCode ^ email.hashCode ^ (name?.hashCode ?? 0) ^ (phone?.hashCode ?? 0);

  @override
  String toString() =>
      'AuthUser(id: $id, email: $email, name: $name, phone: $phone, confirmed: $isEmailConfirmed)';
}
