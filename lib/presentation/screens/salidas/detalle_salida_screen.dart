import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/firestore_service.dart';
import '../../../data/datasources/remote/auth_service.dart';
import 'chat_salida_screen.dart';

final _salidaLiveProvider =
    StreamProvider.family<SalidaGrupal?, String>((ref, tripId) {
  return FirestoreService.instance.streamSalidaPorId(tripId);
});

class DetalleSalidaScreen extends ConsumerWidget {
  final SalidaGrupal salida;
  const DetalleSalidaScreen({super.key, required this.salida});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fid = salida.firestoreId;
    final salidaLive = fid != null
        ? ref.watch(_salidaLiveProvider(fid)).asData?.value ?? salida
        : salida;

    final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = salidaLive.fechaHora;
    final usuario = AuthService.instance.usuarioActual;
    final uid = usuario?.googleId ?? usuario?.usuarioId.toString() ?? '';
    final yaAnotado = salidaLive.participantes
        .any((p) => p.nombre == uid || p.usuarioId.toString() == uid);
    final soyCreadador = salidaLive.organizadorId.toString() == uid;

    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Detalle de salida'),
        actions: [
          if (fid != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: SupColors.cyanNeon),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatSalidaScreen(salida: salidaLive)))),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SupColors.cyanNeon),
            onPressed: () async {
              await Share.share(
                '🏄 Salida grupal SUP\n'
                '📍 ${salidaLive.spotNombre}\n'
                '📅 ${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} '
                '${dt.hour.toString().padLeft(2,'0')}:00\n'
                '👥 ${salidaLive.participantes.length}/${salidaLive.cuposMax} anotados\n#SUPReady');
            }),
          if (soyCreadador && salidaLive.activa && fid != null)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: SupColors.semaforoRojo),
              onPressed: () => _cancelar(context, fid)),
        ],
      ),
      bottomNavigationBar: salidaLive.activa && !soyCreadador
          ? SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _BotonAnotarse(salida: salidaLive, yaAnotado: yaAnotado, uid: uid)))
          : null,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Mapa
        Container(height: 180,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SupColors.divider)),
          clipBehavior: Clip.hardEdge,
          child: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-38.0055, -57.5426), initialZoom: 12,
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
              decoration: BoxDecoration(color: SupColors.cyanNeonDim, borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${dt.day}', style: const TextStyle(color: SupColors.cyanNeon,
                    fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 24)),
                Text(meses[dt.month], style: SupTextStyles.label.copyWith(fontSize: 10)),
              ])),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${dias[dt.weekday-1]} ${dt.day} de ${meses[dt.month]}', style: SupTextStyles.heading2),
              Text('${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} hs',
                  style: SupTextStyles.body),
            ])])),
        const SizedBox(height: 12),
        // Info chips
        Wrap(spacing: 10, runSpacing: 8, children: [
          _chip(Icons.people, '${salidaLive.participantes.length}/${salidaLive.cuposMax}',
              salidaLive.llena ? SupColors.semaforoRojo : SupColors.semaforoVerde),
          _chip(Icons.signal_cellular_alt, _labelNivel(salidaLive.nivelMinimo), SupColors.cyanNeon),
          _chip(salidaLive.esPublica ? Icons.public : Icons.lock_outline,
              salidaLive.esPublica ? 'Pública' : 'Privada', SupColors.textSecondary),
        ]),
        const SizedBox(height: 16),
        if (salidaLive.descripcion.isNotEmpty) ...[
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: SupColors.surface,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: SupColors.divider)),
            child: Text(salidaLive.descripcion, style: SupTextStyles.body.copyWith(height: 1.6))),
          const SizedBox(height: 16),
        ],
        // Participantes en tiempo real
        Row(children: [
          Text('Participantes (${salidaLive.participantes.length})', style: SupTextStyles.heading2),
          const Spacer(),
          if (fid != null) ...[
            const Icon(Icons.circle, color: SupColors.semaforoVerde, size: 8),
            const SizedBox(width: 4),
            Text('En vivo', style: SupTextStyles.body.copyWith(fontSize: 11, color: SupColors.semaforoVerde)),
          ],
        ]),
        const SizedBox(height: 12),
        salidaLive.participantes.isEmpty
            ? Container(padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: SupColors.surface,
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: SupColors.divider)),
                child: const Center(child: Text('Sé el primero en anotarte 👋', style: SupTextStyles.body)))
            : Column(children: salidaLive.participantes.asMap().entries
                .map((e) => _buildParticipante(e.value, e.key == 0)).toList()),
        const SizedBox(height: 80),
      ]),
    );
  }

  Future<void> _cancelar(BuildContext context, String tripId) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: SupColors.surface,
      title: const Text('Cancelar salida', style: TextStyle(color: SupColors.textPrimary,
          fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
      content: const Text('¿Cancelar esta salida?',
          style: TextStyle(color: SupColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('NO', style: TextStyle(color: SupColors.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('CANCELAR', style: TextStyle(color: SupColors.semaforoRojo))),
      ]));
    if (ok != true) return;
    await FirestoreService.instance.cancelarSalida(tripId);
    if (context.mounted) Navigator.pop(context);
  }

  Widget _buildParticipante(ParticipanteSalida p, bool esOrg) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: SupColors.surface,
        borderRadius: BorderRadius.circular(12), border: Border.all(color: SupColors.divider)),
    child: Row(children: [
      CircleAvatar(radius: 20, backgroundColor: SupColors.cyanNeonDim,
        backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
        child: p.avatarUrl == null ? Text(
            p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
            style: const TextStyle(color: SupColors.cyanNeon, fontWeight: FontWeight.w700, fontSize: 16))
            : null),
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
    NivelSalida.todos: 'Todos', NivelSalida.principiante: 'Principiante+',
    NivelSalida.intermedio: 'Intermedio+', NivelSalida.avanzado: 'Solo avanzados',
  }[n]!;
}

class _BotonAnotarse extends ConsumerStatefulWidget {
  final SalidaGrupal salida;
  final bool yaAnotado;
  final String uid;
  const _BotonAnotarse({required this.salida, required this.yaAnotado, required this.uid});
  @override
  ConsumerState<_BotonAnotarse> createState() => _BotonAnotarseState();
}

class _BotonAnotarseState extends ConsumerState<_BotonAnotarse> {
  bool _procesando = false;

  Future<void> _anotarse() async {
    final usuario = AuthService.instance.usuarioActual;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Iniciá sesión para anotarte'), backgroundColor: SupColors.surface));
      return;
    }
    final fid = widget.salida.firestoreId;
    if (fid == null) return;
    setState(() => _procesando = true);
    await FirestoreService.instance.anotarseEnSalida(fid, usuario);
    await FirestoreService.instance.upsertPerfil(usuario);
    setState(() => _procesando = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('¡Te anotaste! 🏄'), backgroundColor: SupColors.semaforoVerde));
  }

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: (widget.yaAnotado || widget.salida.llena || _procesando) ? null : _anotarse,
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 56),
      backgroundColor: widget.yaAnotado ? SupColors.surface : SupColors.cyanNeon,
      foregroundColor: widget.yaAnotado ? SupColors.textSecondary : SupColors.backgroundDeep),
    child: Text(
      _procesando ? 'PROCESANDO...' : widget.yaAnotado ? '✓ YA ESTÁS ANOTADO'
          : widget.salida.llena ? 'SALIDA COMPLETA' : 'ANOTARME A ESTA SALIDA',
      style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 16)));
}
