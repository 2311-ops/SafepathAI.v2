/// Fixed family-circle role set â€” used to seed the user's profile metadata
/// during Supabase sign-up and to keep the existing role-selection UI intact.
enum Role {
  guardian('Guardian'),
  member('Member'),
  caregiver('Caregiver'),
  orgAdmin('OrgAdmin');

  const Role(this.wireValue);

  final String wireValue;

  static Role fromWire(String value) => Role.values.firstWhere(
    (role) => role.wireValue == value,
    orElse: () => throw ArgumentError('Unknown role: $value'),
  );
}
