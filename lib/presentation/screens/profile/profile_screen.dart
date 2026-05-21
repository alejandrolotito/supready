import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _cargando = false;

  Future<void> _login() async {
    setState(() => _cargando = true);
    final result = await AuthService.instance.signInConGoogle();
    setState(() => _cargando = false);
    if (result.exitoso && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido ${result.usuario!.nombreCompleto}!'),
          backgroundColor: SupColors.semaforoVerde,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioActual;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: usuario != null
              ? _buildPerfil(usuario)
              : _buildLogin(),
        ),
      ),
    );
  }

  Widget _buildLogin() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.person_outline, size: 80, color: SupColors.cyanNeon),
      const SizedBox(height: 24),
      const Text('Iniciá sesión para guardar tus remadas', style: SupTextStyles.body, textAlign: TextAlign.center),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        onPressed: _cargando ? null : _login,
        icon: _cargando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: SupColors.backgroundDeep))
            : const Icon(Icons.login),
        label: Text(_cargando ? 'CONECTANDO...' : 'CONTINUAR CON GOOGLE'),
      ),
    ],
  );

  Widget _buildPerfil(UsuarioModel usuario) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircleAvatar(
        radius: 48,
        backgroundColor: SupColors.cyanNeonDim,
        backgroundImage: usuario.avatarUrl != null ? NetworkImage(usuario.avatarUrl!) : null,
        child: usuario.avatarUrl == null ? const Icon(Icons.person, size: 48, color: SupColors.cyanNeon) : null,
      ),
      const SizedBox(height: 16),
      Text(usuario.nombreCompleto, style: SupTextStyles.heading2),
      const SizedBox(height: 4),
      Text(usuario.email, style: SupTextStyles.body),
      const SizedBox(height: 32),
      OutlinedButton(
        onPressed: () async { await AuthService.instance.signOut(); setState(() {}); },
        style: OutlinedButton.styleFrom(foregroundColor: SupColors.semaforoRojo, side: const BorderSide(color: SupColors.semaforoRojo)),
        child: const Text('CERRAR SESIÓN'),
      ),
    ],
  );
}
