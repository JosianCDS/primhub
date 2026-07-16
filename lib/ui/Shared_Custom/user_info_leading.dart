import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:go_router/go_router.dart';
class UserInfoLeading extends StatelessWidget {
  const UserInfoLeading({super.key});

  @override
  Widget build(BuildContext context) {
    String username = 'Usuario';
    String roleName = 'Usuario';

    try {
      final payload = Token.decodePayload(Token.token);
      username = payload['sub'] ?? 'Usuario';

      // Sobrescribimos el rol del payload para asegurar la nomenclatura estricta solicitada
      if (AccessControl.isRealAdmin) {
        roleName = 'Administrador';
      } else if (AccessControl.isRealSupport) {
        roleName = 'Usuario de Soporte';
      } else if (AccessControl.isRealProject) {
        roleName = 'Usuario de Proyecto';
      }
    } catch (_) {}

    return InkWell(
      onTap: () => context.push('/profile'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF649E49), // Verde del logo
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  roleName,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
