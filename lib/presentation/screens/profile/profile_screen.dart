import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/stats_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _cargando = false;
  EstadisticasUsuario? _stats;
  final _nombreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarStats();
  }

  Future<void> _cargarStats() async {
    final usuario = AuthService.instance.usuarioActual;
    final stats = await StatsRepository.instance.calcular(usuario?.usuarioId);
    if (mounted) setState(() => _stats = stats);
  }

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
      Container(width: 90, height: 90,
        decoration: BoxDecoration(shape: BoxShape.circle, color: SupColors.surface,
            border: Border.all(color: SupColors.cyanNeon, width: 2)),
        child: const Icon(Icons.person_outline, size: 48, color: SupColors.cyanNeon)),
      const SizedBox(height: 24),
      const Text('Ingresá a SUPReady', style: SupTextStyles.heading2),
      const SizedBox(height: 8),
      const Text('Guardá tus rutas y conectate con otros palistas',
          style: SupTextStyles.body, textAlign: TextAlign.center),
      const SizedBox(height: 32),
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
      TextField(
        controller: _nombreCtrl,
        style: const TextStyle(color: SupColors.textPrimary),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Tu nombre',
          hintStyle: const TextStyle(color: SupColors.textSecondary),
          filled: true, fillColor: SupColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.cyanNeon, width: 1.5)),
          prefixIcon: const Icon(Icons.person, color: SupColors.textSecondary)),
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
      // Info Firebase
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: SupColors.surface,
            borderRadius: BorderRadius.circular(12),
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
          _paso('4', 'Bajar google-services.json → android/app/'),
          _paso('5', 'Habilitar Authentication → Google'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(
                  text: 'keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Comando copiado'),
                backgroundColor: SupColors.semaforoVerde));
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: SupColors.backgroundDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SupColors.divider)),
              child: const Row(children: [
                Expanded(child: Text('keytool -list -v -keystore ~/.android/debug.keystore ...',
                    style: TextStyle(color: SupColors.textSecondary,
                        fontFamily: 'JetBrainsMono', fontSize: 10),
                    overflow: TextOverflow.ellipsis)),
                Icon(Icons.copy, color: SupColors.cyanNeon, size: 14),
              ])),
          ),
        ]),
      ),
    ]),
  );

  Widget _paso(String num, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 18, height: 18, margin: const EdgeInsets.only(right: 8, top: 1),
        decoration: BoxDecoration(shape: BoxShape.circle, color: SupColors.cyanNeonDim,
            border: Border.all(color: SupColors.cyanNeon, width: 1)),
        child: Center(child: Text(num, style: const TextStyle(
            color: SupColors.cyanNeon, fontSize: 10,
            fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)))),
      Expanded(child: Text(texto, style: SupTextStyles.body.copyWith(fontSize: 12))),
    ]),
  );

  Widget _buildPerfil(UsuarioModel usuario) {
    final esInvitado = usuario.email == 'invitado@supready.local';
    final stats = _stats;
    return RefreshIndicator(
      color: SupColors.cyanNeon, backgroundColor: SupColors.surface,
      onRefresh: _cargarStats,
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 8),
        // Avatar
        Center(child: Stack(alignment: Alignment.bottomRight, children: [
          CircleAvatar(radius: 52, backgroundColor: SupColors.surface,
            backgroundImage: usuario.avatarUrl != null
                ? NetworkImage(usuario.avatarUrl!) : null,
            child: usuario.avatarUrl == null
                ? Text(usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(color: SupColors.cyanNeon, fontSize: 36,
                        fontWeight: FontWeight.w700))
                : null),
          if (!esInvitado)
            Container(width: 24, height: 24,
              decoration: const BoxDecoration(shape: BoxShape.circle,
                  color: SupColors.semaforoVerde),
              child: const Icon(Icons.check, color: Colors.white, size: 14)),
        ])),
        const SizedBox(height: 14),
        Center(child: Text(usuario.nombreCompleto, style: SupTextStyles.heading2)),
        Center(child: Text(esInvitado ? 'Modo invitado' : usuario.email,
            style: SupTextStyles.body)),
        if (esInvitado) ...[
          const SizedBox(height: 8),
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: SupColors.semaforoAmarillo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SupColors.semaforoAmarillo.withOpacity(0.5))),
            child: const Text('Modo invitado · datos solo en este dispositivo',
                style: TextStyle(color: SupColors.semaforoAmarillo,
                    fontFamily: 'SpaceGrotesk', fontSize: 11)))),
        ],
        const SizedBox(height: 28),

        // ── Stats reales ──────────────────────────────────
        if (stats != null) ...[
          const Text('Mis estadísticas', style: SupTextStyles.heading2),
          const SizedBox(height: 12),
          // Fila 1
          Row(children: [
            _statCard('Total km', stats.totalKmStr, Icons.straighten),
            const SizedBox(width: 10),
            _statCard('Sesiones', '${stats.totalRutas}', Icons.surfing),
            const SizedBox(width: 10),
            _statCard('Tiempo total', stats.tiempoTotalStr, Icons.timer_outlined),
          ]),
          const SizedBox(height: 10),
          // Fila 2
          Row(children: [
            _statCard('Vel. media', stats.velMediaStr, Icons.speed),
            const SizedBox(width: 10),
            _statCard('Vel. máxima', stats.velMaxStr, Icons.rocket_launch_outlined),
            const SizedBox(width: 10),
            _statCard('Racha', '${stats.rachaActualDias} días', Icons.local_fire_department_outlined),
          ]),
          const SizedBox(height: 10),
          // Este mes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: SupColors.cyanNeonDim,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SupColors.cyanNeon.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.calendar_month, color: SupColors.cyanNeon),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Este mes', style: SupTextStyles.label),
                Text('${stats.rutasMes} salidas · ${stats.kmMes.toStringAsFixed(1)} km',
                    style: const TextStyle(color: SupColors.textPrimary,
                        fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
        ],

        const Divider(color: SupColors.divider),
        const SizedBox(height: 16),

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
      ]),
    );
  }

  Widget _statCard(String label, String valor, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SupColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SupColors.divider)),
      child: Column(children: [
        Icon(icon, color: SupColors.cyanNeon, size: 20),
        const SizedBox(height: 6),
        Text(valor, style: const TextStyle(color: SupColors.textPrimary,
            fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 14),
            textAlign: TextAlign.center),
        Text(label, style: SupTextStyles.body.copyWith(fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  Future<void> _loginGoogle() async {
    setState(() => _cargando = true);
    final result = await AuthService.instance.signInConGoogle();
    setState(() => _cargando = false);
    if (!mounted) return;
    if (result.exitoso) {
      await _cargarStats();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('¡Bienvenido ${result.usuario!.nombre}! 🏄'),
        backgroundColor: SupColors.semaforoVerde));
    } else if (result.errorConfig) {
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: SupColors.surface,
        title: const Text('Google Sign-In no configurado',
            style: TextStyle(color: SupColors.textPrimary, fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700)),
        content: const Text('Necesitás configurar Firebase. Podés usar el modo invitado mientras tanto.',
            style: TextStyle(color: SupColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO', style: TextStyle(color: SupColors.cyanNeon))),
        ],
      ));
    }
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
    await _cargarStats();
    setState(() => _cargando = false);
    if (mounted) setState(() {});
  }
}
