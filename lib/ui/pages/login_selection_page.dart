import 'package:flutter/material.dart';
import 'package:primhub/api/auth_api.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';

class LoginSelectionPage extends StatefulWidget {
  const LoginSelectionPage({super.key});

  @override
  State<LoginSelectionPage> createState() => _LoginSelectionPageState();
}

class _LoginSelectionPageState extends State<LoginSelectionPage> {
  String? _tempToken;
  String? _username;
  String? _password;
  List<dynamic> _clients = [];

  int? _selectedClientId;
  int? _selectedRoleId;
  int? _selectedOrgId;
  int? _selectedWarehouseId;

  List<dynamic> _roles = [];
  List<dynamic> _orgs = [];
  List<dynamic> _warehouses = [];

  bool _isLoading = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _tempToken = args['token'];
        _clients = args['clients'] ?? [];
        _username = args['username'];
        _password = args['password'];
        Token.preAuth = _tempToken;
      }
      _isInit = false;
    }
  }

  String _getName(dynamic item) {
    if (item is Map) {
      return item['name'] ?? item['identifier'] ?? item['id'].toString();
    }
    return item.toString();
  }

  Future<void> _onClientChanged(int? clientId) async {
    if (clientId == null) return;
    setState(() {
      _selectedClientId = clientId;
      _selectedRoleId = null;
      _selectedOrgId = null;
      _selectedWarehouseId = null;
      _roles = [];
      _orgs = [];
      _warehouses = [];
      _isLoading = true;
    });

    final roles = await AuthApi.getRoles(clientId, _tempToken!);

    if (mounted) {
      setState(() {
        _roles = roles;
        _isLoading = false;
      });
    }
  }

  Future<void> _onRoleChanged(int? roleId) async {
    if (roleId == null) return;
    setState(() {
      _selectedRoleId = roleId;
      _selectedOrgId = null;
      _selectedWarehouseId = null;
      _orgs = [];
      _warehouses = [];
      _isLoading = true;
    });

    final orgs = await AuthApi.getOrgs(_selectedClientId!, roleId, _tempToken!);

    if (mounted) {
      setState(() {
        _orgs = orgs;
        _isLoading = false;
      });
    }
  }

  Future<void> _onOrgChanged(int? orgId) async {
    if (orgId == null) return;
    setState(() {
      _selectedOrgId = orgId;
      _selectedWarehouseId = null;
      _warehouses = [];
      _isLoading = true;
    });

    final warehouses = await AuthApi.getWarehouses(
      _selectedClientId!,
      _selectedRoleId!,
      orgId,
      _tempToken!,
    );

    if (mounted) {
      setState(() {
        _warehouses = warehouses;
        _isLoading = false;
      });
    }
  }

  Future<void> _finalizeLogin() async {
    if (_selectedClientId == null ||
        _selectedRoleId == null ||
        _selectedOrgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione Empresa, Rol y Organización'),
        ),
      );
      return;
    }

    if (_username == null || _password == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de credenciales. Vuelva a iniciar sesión.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    Token.client = _selectedClientId;
    Token.rol = _selectedRoleId;
    Token.organitation = _selectedOrgId;
    Token.warehouseID = _selectedWarehouseId;

    Map<String, dynamic> params = {
      "clientId": _selectedClientId,
      "roleId": _selectedRoleId,
      "organizationId": _selectedOrgId,
      "language": "es_CO",
    };
    if (_selectedWarehouseId != null) {
      params["warehouseId"] = _selectedWarehouseId;
    }

    final response = await AuthApi.finalizeLogin(
      _username!,
      _password!,
      params,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (response.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error']),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        Token.auth = response['token'];
        Token.refreshToken = response['refresh_token'];
        CurrentLogMessage.add("Login exitoso. Token guardado.");
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(29),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(21),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Selección de Contexto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomDropdown<int>(
                    value: _selectedClientId,
                    label: 'Empresa',
                    hintText: 'Seleccione Empresa',
                    items: _clients
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(_getName(c)),
                          ),
                        )
                        .toList(),
                    onChanged: _onClientChanged,
                  ),
                  const SizedBox(height: 16),
                  CustomDropdown<int>(
                    value: _selectedRoleId,
                    label: 'Rol',
                    hintText: 'Seleccione Rol',
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem<int>(
                            value: r['id'],
                            child: Text(_getName(r)),
                          ),
                        )
                        .toList(),
                    onChanged: _selectedClientId == null
                        ? null
                        : _onRoleChanged,
                  ),
                  const SizedBox(height: 16),
                  CustomDropdown<int>(
                    value: _selectedOrgId,
                    label: 'Organización',
                    hintText: 'Seleccione Organización',
                    items: _orgs
                        .map(
                          (o) => DropdownMenuItem<int>(
                            value: o['id'],
                            child: Text(_getName(o)),
                          ),
                        )
                        .toList(),
                    onChanged: _selectedRoleId == null ? null : _onOrgChanged,
                  ),
                  const SizedBox(height: 16),
                  if (_warehouses.isNotEmpty)
                    CustomDropdown<int>(
                      value: _selectedWarehouseId,
                      label: 'Almacén (Opcional)',
                      hintText: 'Seleccione Almacén',
                      items: _warehouses
                          .map(
                            (w) => DropdownMenuItem<int>(
                              value: w['id'],
                              child: Text(_getName(w)),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedWarehouseId = val),
                    ),
                  if (_warehouses.isNotEmpty) const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Ingresar',
                    onPressed: _finalizeLogin,
                    isLoading: _isLoading,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
