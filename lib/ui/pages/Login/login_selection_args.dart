class LoginSelectionArgs {
  const LoginSelectionArgs({
    required this.token,
    required this.clients,
    required this.username,
    required this.password,
  });

  final String token;
  final List<dynamic> clients;
  final String username;
  final String password;
}
