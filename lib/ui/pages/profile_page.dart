import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api/token.dart';
import '../widgets/custom_drawer.dart';
import '../shared/custom_modal.dart';
import '../../theme/theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _userInfo = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    try {
      String token = Token.token;
      if (token.startsWith('Bearer ')) {
        token = token.substring(7);
      }
      final payload = _parseJwt(token);
      setState(() {
        _userInfo = payload;
      });
    } catch (e) {
      debugPrint('Error decoding token: $e');
    }
  }

  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) return {};
    return payloadMap;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }
    return utf8.decode(base64Url.decode(output));
  }

  void _showChangePhotoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomModal(
          title: 'Cambiar foto de perfil',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Seleccionar de galería'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mapeo de nombres amigables basado en el token
    final String username = _userInfo['sub'] ?? 'Desconocido';
    final int roleId = _userInfo['AD_Role_ID'] ?? 0;
    final int clientId = _userInfo['AD_Client_ID'] ?? 0;
    final int orgId = _userInfo['AD_Org_ID'] ?? 0;
    final int userId = _userInfo['AD_User_ID'] ?? 0;
    final String language = _userInfo['AD_Language'] ?? 'es_PA';

    final String roleName = roleId == 102 ? 'GardenWorld Admin' : 'Rol $roleId';
    final String clientName = clientId == 11
        ? 'GardenWorld'
        : 'Cliente $clientId';
    final String orgName = orgId == 0
        ? '*'
        : (orgId == 11 ? 'HQ' : 'Org $orgId');

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de Usuario')),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _showChangePhotoDialog(context),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF4F47E5),
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showChangePhotoDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(blurRadius: 2, color: Colors.black26),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Color(0xFF4F47E5),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              username,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              roleName,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoTile(
                      Icons.business,
                      'Empresa / Cliente',
                      clientName,
                    ),
                    const Divider(),
                    _buildInfoTile(Icons.domain, 'Organización', orgName),
                    const Divider(),
                    _buildInfoTile(
                      Icons.badge,
                      'ID de Usuario',
                      userId.toString(),
                    ),
                    const Divider(),
                    _buildInfoTile(Icons.language, 'Idioma', language),
                    const Divider(),
                    _buildInfoTile(
                      Icons.security,
                      'ID de Rol',
                      roleId.toString(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: AppThemes.themeModeNotifier,
                builder: (context, mode, child) {
                  return SwitchListTile(
                    secondary: const Icon(
                      Icons.dark_mode,
                      color: Color(0xFF4F47E5),
                    ),
                    title: const Text(
                      'Modo Oscuro',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: mode == ThemeMode.dark,
                    onChanged: (bool value) {
                      AppThemes.themeModeNotifier.value = value
                          ? ThemeMode.dark
                          : ThemeMode.light;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4F47E5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
