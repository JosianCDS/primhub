import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:primhub/api/api_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../api/token.dart';
import '../../widgets/custom_drawer.dart';
import '../../Shared_Custom/custom_modal.dart';
import '../../../theme/theme.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/api_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _userInfo = {};
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    if (User.profileImageBytes != null) {
      _profileImageBytes = User.profileImageBytes;
    } else {
      _loadPartnerLogo();
    }
  }

  Future<void> _loadPartnerLogo() async {
    int? partnerId = User.cBPartnerID;

    // Fallback: Si no hay ID en memoria, intentamos recuperarlo del usuario actual
    if (partnerId == null) {
      try {
        final payload = Token.decodePayload(Token.token);
        final userId = payload['AD_User_ID'];
        if (userId != null) {
          final userUrl = Uri.parse('${Endpoint.adUser}/$userId?\$select=C_BPartner_ID');
          final userResp = await http.get(userUrl, headers: {'Authorization': Token.token});
          if (userResp.statusCode == 200) {
            final userData = json.decode(utf8.decode(userResp.bodyBytes));
            final bpField = userData['C_BPartner_ID'];
            if (bpField is Map)
              partnerId = bpField['id'];
            else if (bpField is int)
              partnerId = bpField;
            if (partnerId != null) User.cBPartnerID = partnerId; // Guardar en memoria
          }
        }
      } catch (_) {}
    }

    if (partnerId == null) return;

    try {
      // 1. Obtener Logo_ID del Tercero (C_BPartner)
      final bpUrl = Uri.parse('${Endpoint.cBPartner}/$partnerId?\$select=Logo_ID');
      final bpResponse = await http.get(bpUrl, headers: {'Authorization': Token.token});

      if (bpResponse.statusCode == 200) {
        final bpData = json.decode(utf8.decode(bpResponse.bodyBytes));
        final logoField = bpData['Logo_ID'];
        int? logoId;
        if (logoField is Map) {
          logoId = logoField['id'];
        } else if (logoField is int) {
          logoId = logoField;
        }

        if (logoId != null) {
          // 2. Obtener BinaryData de la imagen (AD_Image)
          final imgUrl = Uri.parse('${Endpoint.baseUrl}/api/v1/models/AD_Image/$logoId?\$select=BinaryData');
          final imgResponse = await http.get(imgUrl, headers: {'Authorization': Token.token});
          if (imgResponse.statusCode == 200) {
            final imgData = json.decode(utf8.decode(imgResponse.bodyBytes));
            final binaryData = imgData['BinaryData'];
            if (binaryData is String && binaryData.isNotEmpty) {
              try {
                final cleanBase64 = binaryData.replaceAll(RegExp(r'\s+'), '');
                final bytes = base64Decode(cleanBase64);
                User.profileImageBytes = bytes; // Guardar en caché
                if (mounted)
                  setState(() {
                    _profileImageBytes = bytes;
                  });
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {}
  }

  void _loadUserInfo() {
    try {
      final payload = Token.decodePayload(Token.token);
      setState(() {
        _userInfo = payload;
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    // Mapeo de nombres amigabless basado en el token
    final String username = _userInfo['sub'] ?? 'Desconocido';
    final int roleId = _userInfo['AD_Role_ID'] ?? 0;
    final int clientId = _userInfo['AD_Client_ID'] ?? 0;
    final int orgId = _userInfo['AD_Org_ID'] ?? 0;
    final String language = _userInfo['AD_Language'] ?? 'es_PA';
    final String email = _userInfo['email'] ?? 'admin@gardenworld.com';
    final String bPartner = _userInfo['bpartner_name'] ?? 'GardenWorld HQ';

    String roleFallback = 'Usuario';
    if (AccessControl.isRealAdmin) {
      roleFallback = 'Administrador';
    } else if (AccessControl.isRealSupport) {
      roleFallback = 'Soporte Técnico';
    } else if (AccessControl.isRealProject) {
      roleFallback = 'Cliente / Proyecto';
    }
    final String roleName = _userInfo['role_name'] ?? _userInfo['roleName'] ?? roleFallback;
    final String clientName = _userInfo['client_name'] ?? _userInfo['clientName'] ?? (clientId == 11 ? 'GardenWorld' : 'Cliente $clientId');
    final String orgName = orgId == 0 ? '*' : (orgId == 11 ? 'HQ' : 'Org $orgId');

    return Scaffold(
      appBar: AppBar(
        leading: !AccessControl.isAdmin ? IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Volver al Inicio', onPressed: () => context.go('/')) : null,
        title: const Text('Perfil de Usuario'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refrescar', onPressed: _loadUserInfo),
          if (!AccessControl.isAdmin)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'Cerrar Sesión',
              onPressed: () => showLogoutConfirmation(context),
            ),
        ],
      ),
      drawer: AccessControl.isAdmin ? const CustomDrawer(currentRoute: '/profile') : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF4F47E5),
                      backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                      onBackgroundImageError: _profileImageBytes != null
                          ? (exception, stackTrace) {
                              if (mounted) setState(() => _profileImageBytes = null);
                            }
                          : null,
                      child: _profileImageBytes != null ? null : Text(clientName.isNotEmpty ? clientName[0].toUpperCase() : (username.isNotEmpty ? username[0].toUpperCase() : 'U'), style: const TextStyle(fontSize: 40, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(clientName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(
                username,
                style: TextStyle(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.w500),
              ),
              Text(roleName, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 32),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [_buildInfoTile(Icons.business, 'Empresa / Cliente', clientName), const Divider(), _buildInfoTile(Icons.store, 'Socio de Negocio', bPartner), const Divider(), _buildInfoTile(Icons.domain, 'Organización', orgName), const Divider(), _buildInfoTile(Icons.email, 'Correo Electrónico', email), const Divider(), _buildInfoTile(Icons.language, 'Idioma', language)],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppThemes.themeModeNotifier,
                  builder: (context, mode, child) {
                    return SwitchListTile(
                      secondary: const Icon(Icons.dark_mode, color: Color(0xFF4F47E5)),
                      title: const Text('Modo Oscuro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      value: mode == ThemeMode.dark,
                      onChanged: (bool value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_dark_mode', value);
                        AppThemes.themeModeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
                Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
