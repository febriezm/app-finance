/// Entity AuthUser mewakili pengguna terautentikasi pada MyFinance
class AuthUser {
  final String id;
  final String email;
  final DateTime? createdAt;
  final DateTime? emailConfirmedAt;
  final Map<String, dynamic>? userMetadata;

  const AuthUser({
    required this.id,
    required this.email,
    this.createdAt,
    this.emailConfirmedAt,
    this.userMetadata,
  });

  bool get isEmailConfirmed => emailConfirmedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;

  @override
  String toString() => 'AuthUser(id: $id, email: $email, confirmed: $isEmailConfirmed)';
}
