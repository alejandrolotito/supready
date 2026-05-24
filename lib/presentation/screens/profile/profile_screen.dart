import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/models/models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _cargando = false;
  final _nombreCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioActual;
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: usuario != null ? _buildPerfil(usuario) : _buildLogin(),
    );
  }

  Widget _buildLogin() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const SizedBox(height: 32),
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: SupColors.surface,
          border: Border.all(color: SupColors.cyanNeon, width: 2)),
        child: const Icon(Icons.person_outline, size: 48, color: SupColors.cyanNeon)),
      const SizedBox(height: 24),
      const Text('Ingresá a SUPReady', style: SupTextStyles.heading2),
      const SizedBox(height: 8),
      const Text('Guardá tus rutas y conectate con otros palistas',
          style: SupTextStyles.body, textAlign: TextAlign.center),
      const SizedBox(height: 32),

      // ── Google Sign-In ──
      ElevatedButton.icon(
        onPressed: _cargando ? null : _loginGoogle,
        icon: _cargando
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: SupColors.backgroundDeep))
            : const Icon(Icons.login),
        label: Text(_cargando ? 'CONECTANDO...' : 'CONTINUAR CON GOOGLE'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
      ),

      const SizedBox(height: 16),
      const Row(children: [
        Expanded(child: Divider(color: SupColors.divider)),
        Padding(padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('o', style: SupTextStyles.body)),
        Expanded(child: Divider(color: SupColors.divider)),
      ]),
      const SizedBox(height: 16),

      // ── Modo invitado ──
      TextField(
        controller: _nombreCtrl,
        style: const TextStyle(color: SupColors.textPrimary),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Tu nombre (ej: Ale)',
          hintStyle: const TextStyle(color: SupColors.textSecondary),
          filled: true, fillColor: SupColors.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.divider)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.cyanNeon, width: 1.5)),
          prefixIcon: const Icon(Icons.person, color: SupColors.textSecondary),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _cargando ? null : _loginInvitado,
        style: OutlinedButton.styleFrom(
            foregroundColor: SupColors.cyanNeon,
            side: const BorderSide(color: SupColors.cyanNeon),
            minimumSize: const Size(double.infinity, 52)),
        child: const Text('ENTRAR SIN CUENTA'),
      ),

      const SizedBox(height: 32),
      // ── Instrucciones configuración Google ──
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SupColors.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SupColors.divider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.info_outline, color: SupColors.cyanNeon, size: 16),
            SizedBox(width: 6),
            Text('Para activar Google Sign-In', style: TextStyle(
                color: SupColors.cyanNeon, fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          _paso('1', 'Crear proyecto en Firebase Console'),
          _paso('2', 'Agregar app Android: com.supready.app'),
          _paso('3', 'Agregar SHA-1 del debug keystore'),
          _paso('4', 'Descargar google-services.json → android/app/'),
          _paso('5', 'Habilitar Authentication → Google'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(
                  text: 'keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Comando copiado al portapapeles'),
                backgroundColor: SupColors.semaforoVerde));
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: SupColors.backgroundDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SupColors.divider)),
              child: Row(children: [
                const Expanded(child: Text(
                  'keytool -list -v -keystore ~/.android/debug.keystore ...',
                  style: TextStyle(color: SupColors.textSecondary,
                      fontFamily: 'JetBrainsMono', fontSize: 10),
                  overflow: TextOverflow.ellipsis)),
                const Icon(Icons.copy, color: SupColors.cyanNeon, size: 14),
              ]),
            ),
          ),
        ]),
      ),
    ]),
  );

  Widget _paso(String num, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 18, height: 18, margin: const EdgeInsets.only(right: 8, top: 1),
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: SupColors.cyanNeonDim,
            border: Border.all(color: SupColors.cyanNeon, width: 1)),
        child: Center(child: Text(num, style: const TextStyle(
            color: SupColors.cyanNeon, fontSize: 10,
            fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)))),
      Expanded(child: Text(texto, style: SupTextStyles.body.copyWith(fontSize: 12))),
    ]),
  );

  Widget _buildPerfil(UsuarioModel usuario) {
    final esInvitado = usuario.email == 'invitado@supready.local';
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 16),
      Center(child: Stack(alignment: Alignment.bottomRight, children: [
        CircleAvatar(radius: 52,
          backgroundColor: SupColors.surface,
          backgroundImage: usuario.avatarUrl != null
              ? NetworkImage(usuario.avatarUrl!) : null,
          child: usuario.avatarUrl == null
              ? Text(usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?',
                  style: const TextStyle(color: SupColors.cyanNeon, fontSize: 36,
                      fontWeight: FontWeight.w700))
              : null),
        if (!esInvitado)
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: SupColors.semaforoVerde),
            child: const Icon(Icons.check, color: Colors.white, size: 14)),
      ])),
      const SizedBox(height: 16),
      Center(child: Text(usuario.nombreCompleto,
          style: SupTextStyles.heading2)),
      Center(child: Text(esInvitado ? 'Modo invitado' : usuario.email,
          style: SupTextStyles.body)),
      if (esInvitado) ...[
        const SizedBox(height: 8),
        Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: SupColors.semaforoAmarillo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SupColors.semaforoAmarillo.withOpacity(0.5))),
          child: const Text('Modo invitado — datos solo en este dispositivo',
              style: TextStyle(color: SupColors.semaforoAmarillo,
                  fontFamily: 'SpaceGrotesk', fontSize: 11)))),
      ],
      const SizedBox(height: 32),
      const Divider(color: SupColors.divider),
      _infoRow(Icons.route, 'Rutas guardadas', '—'),
      _infoRow(Icons.straighten, 'Total remado', '—'),
      _infoRow(Icons.speed, 'Vel. media histórica', '—'),
      const Divider(color: SupColors.divider),
      const SizedBox(height: 24),
      if (esInvitado)
        ElevatedButton.icon(
          onPressed: _loginGoogle,
          icon: const Icon(Icons.login),
          label: const Text('VINCULAR CON GOOGLE'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
        )
      else
        OutlinedButton.icon(
          onPressed: () async {
            await AuthService.instance.signOut();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.logout),
          label: const Text('CERRAR SESIÓN'),
          style: OutlinedButton.styleFrom(
              foregroundColor: SupColors.semaforoRojo,
              side: const BorderSide(color: SupColors.semaforoRojo),
              minimumSize: const Size(double.infinity, 52)),
        ),
    ]);
  }

  Widget _infoRow(IconData icon, String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Icon(icon, color: SupColors.cyanNeon, size: 20),
      const SizedBox(width: 12),
      Text(label, style: SupTextStyles.body),
      const Spacer(),
      Text(valor, style: const TextStyle(color: SupColors.textPrimary,
          fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700)),
    ]),
  );

  Future<void> _loginGoogle() async {
    setState(() => _cargando = true);
    final result = await AuthService.instance.signInConGoogle();
    setState(() => _cargando = false);
    if (!mounted) return;
    if (result.exitoso) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('¡Bienvenido ${result.usuario!.nombre}! 🏄'),
        backgroundColor: SupColors.semaforoVerde));
    } else if (result.errorConfig) {
      _mostrarErrorConfig();
    } else if (!result.cancelado) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${result.error ?? "Desconocido"}'),
        backgroundColor: SupColors.surface));
    }
  }

  void _mostrarErrorConfig() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: SupColors.surface,
      title: const Text('Google Sign-In no configurado',
          style: TextStyle(color: SupColors.textPrimary, fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700)),
      content: const Text(
          'Para usar Google Sign-In necesitás configurar Firebase.\n\n'
          'Podés usar el modo invitado mientras tanto — '
          'tus rutas se guardan localmente.',
          style: TextStyle(color: SupColors.textSecondary, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(color: SupColors.cyanNeon))),
      ],
    ));
  }

  Future<void> _loginInvitado() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresá tu nombre primero'),
        backgroundColor: SupColors.surface));
      return;
    }
    setState(() => _cargando = true);
    await AuthService.instance.entrarComoInvitado(nombre);
    setState(() => _cargando = false);
    if (mounted) setState(() {});
  }
}
