import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../api/token.dart';
import '../../api/access_control.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/custom_modal.dart';
import '../shared/custom_button.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
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

        _role = roleId == 102 ? 'GardenWorld Admin' : 'Rol $roleId';
        _client = clientId == 11 ? 'GardenWorld' : 'Cliente $clientId';
      });
    } catch (e) {
      debugPrint('Error decoding token: $e');
    }
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
                  if (_hasSupport || AccessControl.isSupport || AccessControl.isAdmin)
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
                  if (_hasSupport || AccessControl.isSupport || AccessControl.isAdmin)
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

                  /*
                HoverListTile(
                  builder: (isHovered) => ListTile(
                    leading: Icon(
                      Icons.menu_book,
                      color: isHovered
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      'Base de Conocimiento',
                      style: TextStyle(
                        color: isHovered
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/knowledge-base');
                    },
                  ),
                ),
                */
                  if (_hasProject || AccessControl.isProject || AccessControl.isAdmin)
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
                  /*
                  HoverListTile(
                    builder: (isHovered) => ListTile(
                      leading: Icon(
                        Icons.store,
                        color: isHovered
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        'Marketplace',
                        style: TextStyle(
                          color: isHovered
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/marketplace');
                      },
                    ),
                  ),
                  */
                ],
              ),
            ),
            const Divider(),
            HoverListTile(
              builder: (isHovered) => ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 8.0 : 20.0, horizontal: 16.0),
                leading: CircleAvatar(
                  radius: isMobile ? 20 : 30,
                  child: Icon(Icons.person, size: isMobile ? 24 : 40),
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
