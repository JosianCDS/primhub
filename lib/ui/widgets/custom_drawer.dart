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
  final String currentRoute;
  const CustomDrawer({super.key, required this.currentRoute});

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
        final roleId = payload['AD_Role_ID'];
        final clientId = payload['AD_Client_ID'];

        String exactRole = 'Usuario';
        if (AccessControl.isRealAdmin) {
          exactRole = 'Administrador';
        } else if (AccessControl.isRealSupport) {
          exactRole = 'Usuario de Soporte';
        } else if (AccessControl.isRealProject) {
          exactRole = 'Usuario de Proyecto';
        }

        _role = exactRole;
        _client = payload['client_name'] ?? payload['clientName'] ?? (clientId == 11 ? 'GardenWorld' : 'Cliente $clientId');
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: colorScheme.primaryContainer,
                              backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                              child: _profileImageBytes != null ? null : Icon(Icons.person_rounded, size: 28, color: colorScheme.onPrimaryContainer),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _username.isNotEmpty ? _username : 'Nombre',
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _role.isNotEmpty ? _role : 'Rol',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!AccessControl.isAdmin) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.business_rounded, color: colorScheme.primary, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _client.isNotEmpty ? _client : 'Tu Empresa',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_userRolePref != 'PROYECTO')
                    HoverListTile(
                      builder: (isHovered) {
                        bool isSelected = widget.currentRoute == '/';
                        return Container(
                          color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                          child: ListTile(
                            leading: Icon(Icons.home_rounded, color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                            title: Text(
                              'Dashboard',
                              style: TextStyle(color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/');
                            },
                          ),
                        );
                      },
                    ),
                  if (AccessControl.isSupport)
                    HoverListTile(
                      builder: (isHovered) {
                        bool isSelected = widget.currentRoute == '/support';
                        return Container(
                          color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                          child: ListTile(
                            leading: Icon(Icons.schedule_rounded, color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                            title: Text(
                              'Dashboard de Horas',
                              style: TextStyle(color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/support');
                            },
                          ),
                        );
                      },
                    ),
                  if (AccessControl.isSupport)
                    HoverListTile(
                      builder: (isHovered) {
                        bool isSelected = widget.currentRoute == '/my-requests';
                        return Container(
                          color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                          child: ListTile(
                            leading: Icon(Icons.help_rounded, color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                            title: Text(
                              'Mis Solicitudes',
                              style: TextStyle(color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/my-requests');
                            },
                          ),
                        );
                      },
                    ),

                  if (AccessControl.isProject)
                    HoverListTile(
                      builder: (isHovered) {
                        bool isSelected = widget.currentRoute == '/deliverables';
                        return Container(
                          color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                          child: ListTile(
                            leading: Icon(Icons.folder_rounded, color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                            title: Text(
                              'Mis Proyectos',
                              style: TextStyle(color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/deliverables');
                            },
                          ),
                        );
                      },
                    ),

                  HoverListTile(
                    builder: (isHovered) {
                      bool isSelected = widget.currentRoute == '/metrics';
                      return Container(
                        color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                        child: ListTile(
                          leading: Icon(Icons.bar_chart_rounded, color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                          title: Text(
                            'Indicadores (BI)',
                            style: TextStyle(color: isHovered || isSelected ? colorScheme.primary : colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/metrics');
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            HoverListTile(
              builder: (isHovered) => ListTile(
                leading: Icon(Icons.logout_rounded, color: isHovered ? colorScheme.error : colorScheme.onSurfaceVariant),
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
