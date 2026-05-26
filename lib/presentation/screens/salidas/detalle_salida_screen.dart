import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';
import 'chat_salida_screen.dart';

// ============================================================
// SUPReady - Detalle de Salida Grupal
// Info completa + participantes + anotarse + compartir
// ============================================================

class DetalleSalidaScreen extends StatefulWidget {
  final SalidaGrupal salida;
  const DetalleSalidaScreen({super.key, required this.salida});
  @override
  State<DetalleSalidaScreen> createState() => _DetalleSalidaScreenState();
}

class _DetalleSalidaScreenState extends State<DetalleSalidaScreen> {
  late SalidaGrupal _salida;
  bool _procesando = false;

  @override
  void initState() { super.initState(); _salida = widget.salida; }

  bool get _yaSoyParticipante {
    final uid = AuthService.instance.usuarioActual?.usuarioId ?? -1;
    return _salida.participantes.any((p) => p.usuarioId == uid);
  }

  bool get _soyCreadador {
    final uid = AuthService.instance.usuarioActual?.usuarioId ?? -1;
    return _salida.organizadorId == uid;
  }

  Future<void> _anotarse() async {
    final usuario = AuthService.instance.usuarioActual;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Necesitás ingresar para anotarte'),
        backgroundColor: SupColors.surface));
      return;
    }
    setState(() => _procesando = true);
    await SupDatabase.instance.anotarseEnSalida(
      _salida.salidaId ?? 0,
      ParticipanteSalida(
        usuarioId: usuario.usuarioId ?? 0,
        nombre: usuario.nombre,
        avatarUrl: usuario.avatarUrl),
    );
    final salidas = await SupDatabase.instance.getSalidas();
    final actualizada = salidas.firstWhere(
        (s) => s.salidaId == _salida.salidaId, orElse: () => _salida);
    setState(() { _salida = actualizada; _procesando = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('¡Te anotaste! 🏄'), backgroundColor: SupColors.semaforoVerde));
  }

  Future<void> _cancelarSalida() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: SupColors.surface,
        title: const Text('Cancelar salida', style: TextStyle(
            color: SupColors.textPrimary, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        content: const Text('¿Cancelar esta salida? Se avisará a los participantes.',
            style: TextStyle(color: SupColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('NO', style: TextStyle(color: SupColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('CANCELAR', style: TextStyle(color: SupColors.semaforoRojo))),
        ],
      ),
    );
    if (confirmar != true) return;
    await SupDatabase.instance.cancelarSalida(_salida.salidaId ?? 0);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _compartir() async {
    final dias = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = _salida.fechaHora;
    await Share.share(
      '🏄 Salida grupal de SUP\n'
      '📍 ${_salida.spotNombre}\n'
      '📅 ${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} a las ${dt.hour.toString().padLeft(2,'0')}:00\n'
      '👥 ${_salida.participantes.length}/${_salida.cuposMax} palistas anotados\n\n'
      '¡Sumate con SUPReady!',
      subject: 'Salida grupal SUP — ${_salida.spotNombre}');
  }

  @override
  Widget build(BuildContext context) {
    final dias = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = _salida.fechaHora;

    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Detalle de salida'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: SupColors.cyanNeon),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatSalidaScreen(salida: _salida)))),
          IconButton(icon: const Icon(Icons.share_outlined, color: SupColors.cyanNeon),
              onPressed: _compartir),
          if (_soyCreadador)
            IconButton(icon: const Icon(Icons.cancel_outlined, color: SupColors.semaforoRojo),
                onPressed: _cancelarSalida),
        ],
      ),
      bottomNavigationBar: _salida.activa && !_soyCreadador
          ? SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: (_yaSoyParticipante || _salida.llena || _procesando) ? null : _anotarse,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: _yaSoyParticipante ? SupColors.surface : SupColors.cyanNeon,
                  foregroundColor: _yaSoyParticipante ? SupColors.textSecondary : SupColors.backgroundDeep),
                child: Text(
                  _procesando ? 'PROCESANDO...'
                      : _yaSoyParticipante ? '✓ YA ESTÁS ANOTADO'
                      : _salida.llena ? 'SALIDA COMPLETA'
                      : 'ANOTARME A ESTA SALIDA',
                  style: const TextStyle(fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ))
          : null,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Mapa del spot
        Container(
          height: 180, decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SupColors.divider)),
          clipBehavior: Clip.hardEdge,
          child: Stack(children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(-38.0055, -57.5426), // default MDQ
                initialZoom: 13,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.supready.app'),
              ],
            ),
            // Overlay info
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [SupColors.backgroundDeep, SupColors.backgroundDeep.withOpacity(0)])),
                child: Text(_salida.spotNombre,
                    style: SupTextStyles.heading2.copyWith(fontSize: 18)))),
          ]),
        ),
        const SizedBox(height: 16),

        // Fecha y hora destacada
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(14), border: Border.all(color: SupColors.divider)),
          child: Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: SupColors.cyanNeonDim,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${dt.day}', style: const TextStyle(color: SupColors.cyanNeon,
                    fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 24)),
                Text(meses[dt.month], style: SupTextStyles.label.copyWith(fontSize: 10)),
              ])),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${dias[dt.weekday-1]} ${dt.day} de ${meses[dt.month]}',
                  style: SupTextStyles.heading2),
              Text('${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} hs',
                  style: SupTextStyles.body),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // Info chips
        Wrap(spacing: 10, runSpacing: 8, children: [
          _infoChip(Icons.people, '${_salida.participantes.length}/${_salida.cuposMax} palistas',
              _salida.llena ? SupColors.semaforoRojo : SupColors.semaforoVerde),
          _infoChip(Icons.signal_cellular_alt, _labelNivel(_salida.nivelMinimo), SupColors.cyanNeon),
          _infoChip(_salida.esPublica ? Icons.public : Icons.lock_outline,
              _salida.esPublica ? 'Pública' : 'Privada', SupColors.textSecondary),
        ]),
        const SizedBox(height: 16),

        // Descripción
        if (_salida.descripcion.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: SupColors.surface,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: SupColors.divider)),
            child: Text(_salida.descripcion, style: SupTextStyles.body.copyWith(height: 1.6))),
          const SizedBox(height: 16),
        ],

        // Participantes
        Text('Participantes (${_salida.participantes.length})', style: SupTextStyles.heading2),
        const SizedBox(height: 12),
        if (_salida.participantes.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: SupColors.surface,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: SupColors.divider)),
            child: const Center(child: Text('Sé el primero en anotarte 👋', style: SupTextStyles.body)))
        else
          ..._salida.participantes.asMap().entries.map((e) => _buildParticipante(e.value, e.key == 0)),

        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildParticipante(ParticipanteSalida p, bool esOrganizador) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: SupColors.surface,
        borderRadius: BorderRadius.circular(12), border: Border.all(color: SupColors.divider)),
    child: Row(children: [
      CircleAvatar(
        radius: 20, backgroundColor: SupColors.cyanNeonDim,
        backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
        child: p.avatarUrl == null
            ? Text(p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                style: const TextStyle(color: SupColors.cyanNeon,
                    fontWeight: FontWeight.w700, fontSize: 16))
            : null),
      const SizedBox(width: 12),
      Expanded(child: Text(p.nombre, style: SupTextStyles.heading2.copyWith(fontSize: 15))),
      if (esOrganizador)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withOpacity(0.5))),
          child: const Text('ORGANIZADOR', style: TextStyle(
              color: Colors.amber, fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 0.5))),
    ]),
  );

  Widget _infoChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color), const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w600, fontSize: 12)),
    ]));

  String _labelNivel(NivelSalida n) {
    switch(n) {
      case NivelSalida.todos: return 'Todos los niveles';
      case NivelSalida.principiante: return 'Principiante+';
      case NivelSalida.intermedio: return 'Intermedio+';
      case NivelSalida.avanzado: return 'Solo avanzados';
    }
  }
}
