import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/stats_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _cargando = false;
  EstadisticasUsuario? _stats;
  final _nombreCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _cargarStats(); }

  @override
  void dispose() { _nombreCtrl.dispose(); super.dispose(); }

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
      appBar: AppBar(title: const Text('Mi Perfil'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: SupColors.cyanNeon),
              onPressed: _cargarStats),
        ]),
      body: usuario != null ? _buildPerfil(usuario) : _buildLogin(),
    );
  }

  Widget _buildPerfil(UsuarioModel usuario) {
    final esInvitado = usuario.email == 'invitado@supready.local';
    final uid = usuario.googleId ?? usuario.email;

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
                ? Text(usuario.nombre.isNotEmpty
                    ? usuario.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(color: SupColors.cyanNeon,
                        fontSize: 36, fontWeight: FontWeight.w700))
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
            decoration: BoxDecoration(
                color: SupColors.semaforoAmarillo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SupColors.semaforoAmarillo.withOpacity(0.5))),
            child: const Text('Modo invitado · datos solo en este dispositivo',
                style: TextStyle(color: SupColors.semaforoAmarillo,
                    fontFamily: 'SpaceGrotesk', fontSize: 11)))),
        ],
        const SizedBox(height: 28),

        // ── Stats locales (SQLite) ──────────────────────────
        if (_stats != null) ...[
          const Text('Mis estadísticas', style: SupTextStyles.heading2),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Total km',   _stats!.totalKmStr,    Icons.straighten),
            const SizedBox(width: 10),
            _statCard('Sesiones',  '${_stats!.totalRutas}', Icons.surfing),
            const SizedBox(width: 10),
            _statCard('Tiempo',     _stats!.tiempoTotalStr, Icons.timer_outlined),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _statCard('Vel. media', _stats!.velMediaStr,   Icons.speed),
            const SizedBox(width: 10),
            _statCard('Vel. máx',  _stats!.velMaxStr,      Icons.rocket_launch_outlined),
            const SizedBox(width: 10),
            _statCard('Racha',     '${_stats!.rachaActualDias}d',
                Icons.local_fire_department_outlined),
          ]),
          const SizedBox(height: 10),
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
                Text('${_stats!.rutasMes} salidas · ${_stats!.kmMes.toStringAsFixed(1)} km',
                    style: const TextStyle(color: SupColors.textPrimary,
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
            ])),
          const SizedBox(height: 24),
        ],

        // ── Salidas grupales Firestore (Riverpod) ───────────
        if (!esInvitado) ...[
          const Text('Mis salidas grupales', style: SupTextStyles.heading2),
          const SizedBox(height: 12),
          ref.watch(misSalidasProvider(uid)).when(
            loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    color: SupColors.cyanNeon, strokeWidth: 2))),
            error: (e, _) => Text('Error: $e',
                style: SupTextStyles.body.copyWith(fontSize: 12)),
            data: (salidas) => salidas.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: SupColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SupColors.divider)),
                    child: const Text(
                        'Todavía no participás en ninguna salida',
                        style: SupTextStyles.body,
                        textAlign: TextAlign.center))
                : Column(children: salidas.take(5)
                    .map(_buildSalidaRow).toList()),
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
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)))
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
                minimumSize: const Size(double.infinity, 52))),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildSalidaRow(SalidaGrupal s) {
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];
    final estadoColor = _colorEstado(s.estado);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SupColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SupColors.divider)),
      child: Row(children: [
        const Icon(Icons.group, color: SupColors.cyanNeon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.spotNombre,
              style: SupTextStyles.heading2.copyWith(fontSize: 14)),
          Text('${s.fechaHora.day} ${meses[s.fechaHora.month]} · '
              '${s.participantes.length}/${s.cuposMax} palistas',
              style: SupTextStyles.body.copyWith(fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: estadoColor.withOpacity(0.4))),
          child: Text(_labelEstado(s.estado), style: TextStyle(
              color: estadoColor, fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 9))),
      ]));
  }

  Color _colorEstado(EstadoSalida e) => const {
    EstadoSalida.abierta:    SupColors.semaforoVerde,
    EstadoSalida.enCurso:    SupColors.cyanNeon,
    EstadoSalida.finalizada: SupColors.textSecondary,
    EstadoSalida.cancelada:  SupColors.semaforoRojo,
  }[e]!;

  String _labelEstado(EstadoSalida e) => const {
    EstadoSalida.abierta:    'ABIERTA',
    EstadoSalida.enCurso:    'EN CURSO',
    EstadoSalida.finalizada: 'FINALIZADA',
    EstadoSalida.cancelada:  'CANCELADA',
  }[e]!;

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
            fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700,
            fontSize: 14), textAlign: TextAlign.center),
        Text(label, style: SupTextStyles.body.copyWith(fontSize: 10),
            textAlign: TextAlign.center),
      ])));

  Widget _buildLogin() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const SizedBox(height: 32),
      Container(width: 90, height: 90,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: SupColors.surface,
            border: Border.all(color: SupColors.cyanNeon, width: 2)),
        child: const Icon(Icons.person_outline, size: 48,
            color: SupColors.cyanNeon)),
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
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: SupColors.backgroundDeep))
            : const Icon(Icons.login),
        label: Text(_cargando ? 'CONECTANDO...' : 'CONTINUAR CON GOOGLE'),
        style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56))),
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
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: SupColors.cyanNeon, width: 1.5)),
          prefixIcon: const Icon(Icons.person, color: SupColors.textSecondary))),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _cargando ? null : _loginInvitado,
        style: OutlinedButton.styleFrom(
            foregroundColor: SupColors.cyanNeon,
            side: const BorderSide(color: SupColors.cyanNeon),
            minimumSize: const Size(double.infinity, 52)),
        child: const Text('ENTRAR SIN CUENTA')),
      const SizedBox(height: 24),
      // SHA-1 copy helper
      GestureDetector(
        onTap: () {
          Clipboard.setData(const ClipboardData(
              text: 'EC:76:CA:0D:CD:90:B9:75:ED:A9:6D:26:5A:D3:E8:C9:5B:93:34:6D'));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('SHA-1 copiado'),
              backgroundColor: SupColors.semaforoVerde));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SupColors.divider)),
          child: const Row(children: [
            Icon(Icons.fingerprint, color: SupColors.cyanNeon, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
                'SHA-1: EC:76:CA:0D:...34:6D (tap para copiar)',
                style: TextStyle(color: SupColors.textSecondary,
                    fontFamily: 'JetBrainsMono', fontSize: 11))),
            Icon(Icons.copy, color: SupColors.cyanNeon, size: 14),
          ])),
      ),
    ]));

  Future<void> _loginGoogle() async {
    setState(() => _cargando = true);
    final result = await AuthService.instance.signInConGoogle();
    setState(() => _cargando = false);
    if (!mounted) return;
    if (result.exitoso) {
      await _cargarStats();
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Bienvenido ${result.usuario!.nombre}! 🏄'),
          backgroundColor: SupColors.semaforoVerde));
      if (Navigator.canPop(context)) Navigator.pop(context);
    } else if (result.errorConfig) {
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: SupColors.surface,
        title: const Text('Google Sign-In no configurado',
            style: TextStyle(color: SupColors.textPrimary,
                fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        content: const Text(
            'Necesitás configurar Firebase o usar el modo invitado.',
            style: TextStyle(color: SupColors.textSecondary, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO',
                style: TextStyle(color: SupColors.cyanNeon)))],
      ));
    } else if (!result.cancelado && result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${result.error}'),
          backgroundColor: SupColors.surface));
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
    if (mounted) setState(() => _cargando = false);
  }
}
