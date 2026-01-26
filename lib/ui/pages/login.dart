import 'package:flutter/material.dart';
import 'package:primhub/api/auth_api.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late AnimationController _borderAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    _borderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _loadSavedUser();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _userController.dispose();
    _passController.dispose();
    _borderAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_user');
    if (savedUser != null) _userController.text = savedUser;
  }

  void _login() async {
    setState(() {
      _isLoading = true;
    });

    final username = _userController.text.trim();
    final password = _passController.text.trim();

    // 1. Login Inicial (Step 1)
    final responseStep1 = await AuthApi.loginStep1(username, password);

    if (responseStep1.containsKey('error')) {
      _showError(responseStep1['error']);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_user', username);

    String tempToken = responseStep1['token'];
    Token.preAuth = tempToken;

    // Verificar si es login abreviado (ya tenemos token final) o necesitamos seleccionar contexto
    if (responseStep1.containsKey('clients')) {
      // Flujo Normal: Necesitamos seleccionar Cliente -> Rol -> Org
      List clients = responseStep1['clients'];
      if (clients.isEmpty) {
        _showError('El usuario no tiene clientes asignados.');
        return;
      }

      // Lógica de auto-ingreso si hay un solo camino (1 Cliente -> 1 Rol -> 1 Org)
      if (clients.length == 1) {
        final client = clients[0];
        final roles = await AuthApi.getRoles(client['id'], tempToken);

        if (roles.length == 1) {
          final role = roles[0];
          final orgs = await AuthApi.getOrgs(
            client['id'],
            role['id'],
            tempToken,
          );

          if (orgs.length == 1) {
            final org = orgs[0];
            final warehouses = await AuthApi.getWarehouses(
              client['id'],
              role['id'],
              org['id'],
              tempToken,
            );

            // Si hay 0 o 1 almacén, podemos proceder automáticamente
            if (warehouses.length <= 1) {
              int? warehouseId = warehouses.isNotEmpty
                  ? warehouses[0]['id']
                  : null;

              Token.client = client['id'];
              Token.rol = role['id'];
              Token.organitation = org['id'];
              Token.warehouseID = warehouseId;

              Map<String, dynamic> params = {
                "clientId": client['id'],
                "roleId": role['id'],
                "organizationId": org['id'],
                "language": "es_CO",
              };
              if (warehouseId != null) params["warehouseId"] = warehouseId;

              final responseFinal = await AuthApi.finalizeLogin(
                username,
                password,
                params,
              );

              if (!responseFinal.containsKey('error')) {
                Token.auth = responseFinal['token'];
                Token.refreshToken = responseFinal['refresh_token'];

                if (mounted) {
                  setState(() => _isLoading = false);
                  CurrentLogMessage.add("Login exitoso (Auto).");
                  Navigator.pushReplacementNamed(context, '/');
                }
                return;
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushNamed(
          context,
          '/login-selection',
          arguments: {
            'token': tempToken,
            'clients': clients,
            'username': username,
            'password': password,
          },
        );
      }
      return;
    } else {
      // Login Abreviado (Ya tenemos el token final)
      Token.auth = tempToken;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      CurrentLogMessage.add("Login exitoso. Token guardado.");
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Animated Border
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _borderAnimationController,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: SweepGradient(
                                    center: Alignment.center,
                                    colors: [
                                      theme.colorScheme.primary.withOpacity(
                                        0.0,
                                      ),
                                      theme.colorScheme.primary.withOpacity(
                                        0.8,
                                      ),
                                      theme.colorScheme.primaryContainer
                                          .withOpacity(0.8),
                                      theme.colorScheme.primary.withOpacity(
                                        0.0,
                                      ),
                                    ],
                                    stops: const [0.0, 0.4, 0.6, 1.0],
                                    transform: GradientRotation(
                                      _borderAnimationController.value *
                                          2 *
                                          3.14159,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Main Content
                        Container(
                          margin: const EdgeInsets.all(3),
                          padding: const EdgeInsets.all(29),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(21),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 130,
                                width: 130,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Image.asset('assets/LogoPrimHub.png'),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Bienvenido',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Inicia sesión en PrimHub',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 32),
                              TextFormField(
                                controller: _userController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Usuario',
                                  hintText: 'Ingrese su usuario',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  hintText: 'Ingrese su contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                switchInCurve: Curves.elasticOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                child: _isLoading
                                    ? Container(
                                        key: const ValueKey('loading'),
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Bienvenido',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color:
                                                    theme.colorScheme.onPrimary,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : CustomButton(
                                        key: const ValueKey('button'),
                                        text: 'Ingresar',
                                        onPressed: _login,
                                        isLoading: false,
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        borderRadius: 12,
                                      ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
