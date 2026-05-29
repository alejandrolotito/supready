import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/firestore_service.dart';
import '../../../data/datasources/remote/auth_service.dart';
import 'chat_salida_screen.dart';

class DetalleSalidaScreen extends StatefulWidget {
  final SalidaGrupal salida;
  const DetalleSalidaScreen({super.key, required this.salida});
  @override
  State<DetalleSalidaScreen> createState() => _DetalleSalidaScreenState();
}

class _DetalleSalidaScreenState extends State<DetalleSalidaScreen> {
  bool _procesando = false;

  String? get _fid => widget.salida.firestoreId;
  bool get _soyCreadador =>
      widget.salida.organizadorId.toString() ==
      (AuthService.instance.usuarioActual?.googleId ??
       AuthService.instance.usuarioActual?.usuarioId.toString());

  Stream<List<ParticipanteSalida>> get _streamParticipantes =>
      _fid != null
          ? FirestoreService.instance
              .streamMensajes(_fid!) // reuse stream structure
              .map((_) => widget.salida.participantes) // placeholder
          : Stream.value([]);

  Future<void> _anotarse() async {
    final usuario = AuthService.instance.usuarioActual;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Iniciá sesión para anotarte'),
          backgroundColor: SupColors.surface));
      return;
    }
    if (_fid == null) return;
    setState(() => _procesando = true);
    await FirestoreService.instance.anotarseEnSalida(_fid!, usuario);
    await FirestoreService.instance.upsertPerfil(usuario);
    setState(() => _procesando = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('¡Te anotaste! 🏄'), backgroundColor: SupColors.semaforoVerde));
  }

  Future<void> _cancelar() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
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
      ]));
    if (ok != true || _fid == null) return;
    await FirestoreService.instance.cancelarSalida(_fid!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.salida;
    final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = s.fechaHora;
    final usuario = AuthService.instance.usuarioActual;
    final yaAnotado = s.participantes.any((p) =>
        p.usuarioId.toString() == (usuario?.googleId ?? usuario?.usuarioId.toString()));

    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Detalle de salida'),
        actions: [
          if (_fid != null)
            IconButton(icon: const Icon(Icons.chat_bubble_outline, color: SupColors.cyanNeon),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatSalidaScreen(salida: s)))),
          IconButton(icon: const Icon(Icons.share_outlined, color: SupColors.cyanNeon),
              onPressed: () async {
                await Share.share(
                    '🏄 Salida grupal SUP\n'
                    '📍 ${s.spotNombre}\n'
                    '📅 ${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} '
                    '${dt.hour.toString().padLeft(2,'0')}:00\n'
                    '👥 ${s.participantes.length}/${s.cuposMax} anotados\n#SUPReady');
              }),
          if (_soyCreadador && s.activa)
            IconButton(icon: const Icon(Icons.cancel_outlined, color: SupColors.semaforoRojo),
                onPressed: _cancelar),
        ],
      ),
      bottomNavigationBar: s.activa && !_soyCreadador
          ? SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: (yaAnotado || s.llena || _procesando) ? null : _anotarse,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: yaAnotado ? SupColors.surface : SupColors.cyanNeon,
                  foregroundColor: yaAnotado ? SupColors.textSecondary : SupColors.backgroundDeep),
                child: Text(_procesando ? 'PROCESANDO...'
                    : yaAnotado ? '✓ YA ESTÁS ANOTADO'
                    : s.llena ? 'SALIDA COMPLETA'
                    : 'ANOTARME A ESTA SALIDA',
                    style: const TextStyle(fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700, fontSize: 16)))))
          : null,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Mapa
        Container(height: 180,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SupColors.divider)),
          clipBehavior: Clip.hardEdge,
          child: FlutterMap(
            options: const MapOptions(initialCenter: LatLng(-38.0055, -57.5426),
                initialZoom: 12,
                interactionOptions: InteractionOptions(flags: InteractiveFlag.none)),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.supready.app'),
            ])),
        const SizedBox(height: 16),
        // Fecha
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(14), border: Border.all(color: SupColors.divider)),
          child: Row(children: [
            Container(width: 60, height: 60,
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
            ])])),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          _chip(Icons.people, '${s.participantes.length}/${s.cuposMax}',
              s.llena ? SupColors.semaforoRojo : SupColors.semaforoVerde),
          _chip(Icons.signal_cellular_alt, _labelNivel(s.nivelMinimo), SupColors.cyanNeon),
          _chip(s.esPublica ? Icons.public : Icons.lock_outline,
              s.esPublica ? 'Pública' : 'Privada', SupColors.textSecondary),
        ]),
        const SizedBox(height: 16),
        if (s.descripcion.isNotEmpty) ...[
          Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: SupColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SupColors.divider)),
              child: Text(s.descripcion, style: SupTextStyles.body.copyWith(height: 1.6))),
          const SizedBox(height: 16),
        ],
        Text('Participantes (${s.participantes.length})', style: SupTextStyles.heading2),
        const SizedBox(height: 12),
        s.participantes.isEmpty
            ? Container(padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: SupColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SupColors.divider)),
                child: const Center(child: Text('Sé el primero en anotarte 👋',
                    style: SupTextStyles.body)))
            : Column(children: s.participantes.asMap().entries.map((e) =>
                _participante(e.value, e.key == 0)).toList()),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _participante(ParticipanteSalida p, bool esOrg) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: SupColors.surface,
        borderRadius: BorderRadius.circular(12), border: Border.all(color: SupColors.divider)),
    child: Row(children: [
      CircleAvatar(radius: 20, backgroundColor: SupColors.cyanNeonDim,
        backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
        child: p.avatarUrl == null ? Text(
            p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
            style: const TextStyle(color: SupColors.cyanNeon,
                fontWeight: FontWeight.w700, fontSize: 16)) : null),
      const SizedBox(width: 12),
      Expanded(child: Text(p.nombre, style: SupTextStyles.heading2.copyWith(fontSize: 15))),
      if (esOrg) Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.withOpacity(0.5))),
        child: const Text('ORGANIZADOR', style: TextStyle(color: Colors.amber,
            fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 9))),
    ]));

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color), const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w600, fontSize: 12))]));

  String _labelNivel(NivelSalida n) => const {
    NivelSalida.todos: 'Todos los niveles', NivelSalida.principiante: 'Principiante+',
    NivelSalida.intermedio: 'Intermedio+', NivelSalida.avanzado: 'Solo avanzados',
  }[n]!;
}
