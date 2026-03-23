import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import '../../api/token.dart';
import '../../api/access_control.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Shared_Custom/custom_modal.dart';
import '../Shared_Custom/custom_button.dart';
import 'hover_widgets.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _username = '';
  String _role = '';
  String _client = '';
  String _userRolePref = 'ADMIN';
  bool _hasSupport = false;
  bool _hasProject = false;
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
            if (partnerId != null) User.cBPartnerID = partnerId;
          }
        }
      } catch (_) {}
    }

    if (partnerId == null) return;

    try {
      final bpUrl = Uri.parse('${Endpoint.cBPartner}/$partnerId?\$select=Logo_ID');
      final bpResponse = await http.get(bpUrl, headers: {'Authorization': Token.token});
      if (bpResponse.statusCode == 200) {
        final bpData = json.decode(utf8.decode(bpResponse.bodyBytes));
        final logoField = bpData['Logo_ID'];
        int? logoId = (logoField is Map) ? logoField['id'] : (logoField is int ? logoField : null);

        if (logoId != null) {
          final imgUrl = Uri.parse('${Endpoint.baseUrl}/api/v1/models/AD_Image/$logoId?\$select=BinaryData');
          final imgResponse = await http.get(imgUrl, headers: {'Authorization': Token.token});
          if (imgResponse.statusCode == 200) {
            final imgData = json.decode(utf8.decode(imgResponse.bodyBytes));
            final binaryData = imgData['BinaryData'];
            if (binaryData is String && binaryData.isNotEmpty) {
              final bytes = base64Decode(binaryData);
              User.profileImageBytes = bytes; // Guardar en caché
              if (mounted) setState(() => _profileImageBytes = bytes);
            }
          }
        }
      }
    } catch (_) {}
  }

  void _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _userRolePref = prefs.getString('user_role') ?? 'ADMIN';
    _hasSupport = prefs.getBool('has_support') ?? false;
    _hasProject = prefs.getBool('has_project') ?? false;
    try {
      final payload = Token.decodePayload(Token.token);
      setState(() {
        _username = payload['sub'] ?? 'Usuario';
        // Mapeo simple de IDs a Nombres (En producción esto vendría de un endpoint de sesión)
        final roleId = payload['AD_Role_ID'];
        final clientId = payload['AD_Client_ID'];

        _role = payload['roleName'] ?? (roleId == 102 ? 'GardenWorld Admin' : 'Usuario');
        _client = clientId == 11 ? 'GardenWorld' : 'Cliente $clientId';
      });
    } catch (e) {}
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomModal(
          title: 'Cerrar Sesión',
          content: const Text('¿Estás seguro de que quieres cerrar sesión y salir de la aplicación?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            CustomButton(
              text: 'Sí, salir',
              onPressed: () {
                Token.clear();
                context.go('/login');
              },
              backgroundColor: Colors.red,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: theme.drawerTheme.backgroundColor ?? colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: theme.drawerTheme.backgroundColor ?? colorScheme.surface),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.attachment, color: colorScheme.onPrimary),
                        ),
                        const SizedBox(width: 16),
                        Text(_client.isNotEmpty ? _client : 'Tu Empresa', style: TextStyle(color: colorScheme.onSurface, fontSize: 24)),
                      ],
                    ),
                  ),
                  if (_userRolePref != 'PROYECTO')
                    HoverListTile(
                      builder: (isHovered) => ListTile(
                        leading: Icon(Icons.home, color: isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant),
                        title: Text('Inicio', style: TextStyle(color: isHovered ? colorScheme.primary : colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/');
                        },
                      ),
                    ),
                  if (AccessControl.isSupport || (_hasSupport && Token.primConfig == null))
                    HoverListTile(
                      builder: (isHovered) => ListTile(
                        leading: Icon(Icons.schedule, color: isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant),
                        title: Text('Horas de Soporte', style: TextStyle(color: isHovered ? colorScheme.primary : colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/support');
                        },
                      ),
                    ),
                  if (AccessControl.isSupport || (_hasSupport && Token.primConfig == null))
                    HoverListTile(
                      builder: (isHovered) => ListTile(
                        leading: Icon(Icons.help_outline, color: isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant),
                        title: Text('Mis Solicitudes', style: TextStyle(color: isHovered ? colorScheme.primary : colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/my-requests');
                        },
                      ),
                    ),

                  if (AccessControl.isProject || (_hasProject && Token.primConfig == null))
                    HoverListTile(
                      builder: (isHovered) => ListTile(
                        leading: Icon(Icons.folder, color: isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant),
                        title: Text('Mis Proyectos', style: TextStyle(color: isHovered ? colorScheme.primary : colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/deliverables');
                        },
                      ),
                    ),

                  HoverListTile(
                    builder: (isHovered) => ListTile(
                      leading: Icon(Icons.bar_chart, color: isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant),
                      title: Text('Indicadores (BI)', style: TextStyle(color: isHovered ? colorScheme.primary : colorScheme.onSurface)),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/metrics');
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            HoverListTile(
              builder: (isHovered) => ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 8.0 : 20.0, horizontal: 16.0),
                leading: CircleAvatar(
                  radius: isMobile ? 20 : 30,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                  child: _profileImageBytes != null ? null : Icon(Icons.person, size: isMobile ? 24 : 40, color: colorScheme.onPrimaryContainer),
                ),
                title: Text(
                  _username.isNotEmpty ? _username : 'Nombre',
                  style: TextStyle(fontSize: isMobile ? 16 : 22, color: isHovered ? colorScheme.primary : colorScheme.onSurface),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _role.isNotEmpty ? _role : 'Rol',
                      style: TextStyle(fontSize: isMobile ? 12 : 16, color: isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ver perfil',
                      style: TextStyle(fontSize: isMobile ? 11 : 14, color: isHovered ? colorScheme.primary.withOpacity(0.8) : colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),

                onTap: () {
                  Navigator.pop(context); // Cierra el menú
                  context.push('/profile');
                },
              ),
            ),
            HoverListTile(
              builder: (isHovered) => ListTile(
                leading: Icon(Icons.logout, color: isHovered ? colorScheme.error : colorScheme.onSurfaceVariant),
                title: Text('Cerrar sesión', style: TextStyle(color: isHovered ? colorScheme.error : colorScheme.onSurface)),
                onTap: () {
                  Navigator.pop(context); // Cierra el menú
                  _showLogoutDialog(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
