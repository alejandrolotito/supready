import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/tracking_state.dart';
import '../../../data/datasources/local/tracking_service.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/models/models.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  final _svc   = TrackingService.instance;
  final _state = TrackingState.instance;

  StreamSubscription<void>? _sosSub;
  final _mapCtrl = MapController();
  bool _cargando = false;
  bool _mapSiguePosicion = true;
  bool _mostrarStats = false; // toggle stats detalladas

  late AnimationController _longPressCtrl;
  late AnimationController _pulsoCtrl;
  late Animation<double> _pulsoAnim;
  bool _longPressActivo = false;

  @override
  void initState() {
    super.initState();
    _longPressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finalizarTracking();
      });
    _pulsoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulsoAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _pulsoCtrl, curve: Curves.easeInOut));

    _state.addListener(_onStateChanged);
    _sosSub = _svc.sosStream.listen((_) => _mostrarAlertaSOS());
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _longPressCtrl.dispose();
    _pulsoCtrl.dispose();
    _sosSub?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
    final m = _state.metricas;
    if (m != null && _mapSiguePosicion) {
      try {
        _mapCtrl.move(LatLng(m.latitud, m.longitud), _mapCtrl.camera.zoom);
      } catch (_) {}
    }
  }

  Future<void> _iniciarTracking() async {
    setState(() => _cargando = true);
    _state.resetCoordenadas();
    final auth = AuthService.instance.usuarioActual;
    final ok = await _svc.iniciarTracking(
      usuarioId: auth?.usuarioId ?? 1,
      spotId: 1,
      firestoreUserId: auth?.googleId ?? auth?.usuarioId?.toString(),
    );
    if (!ok && mounted) {
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo obtener GPS'),
          backgroundColor: SupColors.surface));
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _cargando = false);
    }
  }

  Future<void> _finalizarTracking() async {
    final ruta = await _svc.finalizarTracking();
    HapticFeedback.heavyImpact();
    _longPressCtrl.reset();
    setState(() => _longPressActivo = false);
    if (ruta != null && mounted) _mostrarResumen(ruta);
  }

  // Color según tramo de velocidad
  Color _colorTramo(TramoVelocidad t) {
    switch (t) {
      case TramoVelocidad.lento:  return SupColors.semaforoVerde;
      case TramoVelocidad.medio:  return SupColors.semaforoAmarillo;
      case TramoVelocidad.rapido: return SupColors.semaforoRojo;
    }
  }

  // Construir polylines coloreadas por tramo de velocidad
  List<Polyline> _buildPolylines(List<PuntoGPS> puntos) {
    if (puntos.length < 2) return [];
    final polylines = <Polyline>[];
    for (int i = 0; i < puntos.length - 1; i++) {
      polylines.add(Polyline(
        points: [
          LatLng(puntos[i].latitud, puntos[i].longitud),
          LatLng(puntos[i+1].latitud, puntos[i+1].longitud),
        ],
        color: _colorTramo(puntos[i].tramo),
        strokeWidth: 4.0,
      ));
    }
    return polylines;
  }

  void _mostrarAlertaSOS() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: SupColors.surface,
          title: const Row(children: [
            Icon(Icons.warning_rounded, color: SupColors.sosRed, size: 26),
            SizedBox(width: 8),
            Flexible(child: Text('SOS — Sin movimiento',
                style: TextStyle(color: SupColors.sosRed,
                    fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 17))),
          ]),
          content: const Text('No se detectó movimiento en 15 min.\n¿Estás bien?',
              style: TextStyle(color: SupColors.textSecondary, height: 1.5)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: SupColors.semaforoVerde,
                  minimumSize: const Size(double.infinity, 48)),
              onPressed: () {
                Navigator.pop(context);
                _svc.confirmarEstoyBien();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Timer SOS reiniciado ✓'),
                    backgroundColor: SupColors.semaforoVerde,
                    duration: Duration(seconds: 2)));
              },
              child: const Text('ESTOY BIEN — SEGUIR REMANDO')),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: SupColors.sosRed,
                  side: const BorderSide(color: SupColors.sosRed),
                  minimumSize: const Size(double.infinity, 48)),
              onPressed: () async {
                Navigator.pop(context);
                final m = _state.metricas;
                final coords = m != null
                    ? '${m.latitud.toStringAsFixed(5)}, ${m.longitud.toStringAsFixed(5)}'
                    : 'desconocida';
                await Share.share(
                    '🆘 EMERGENCIA SUP\nPosición: $coords\n'
                    'Distancia: ${_state.metricas?.distanciaFormateada ?? "?"}');
              },
              child: const Text('ENVIAR ALERTA')),
          ],
        ),
      ),
    );
  }

  void _mostrarResumen(RutaTrazadaModel ruta) {
    final puntos = _svc.puntosGPS;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SupColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResumenRutaSheet(
        ruta: ruta,
        puntos: puntos,
        onCompartir: () async {
          await Share.share(
              '🏄 Remé ${ruta.distanciaKm.toStringAsFixed(2)} km '
              'en ${ruta.duracionMinutos} min\n'
              'Vel. media: ${ruta.velocidadMedia.toStringAsFixed(1)} km/h · '
              'Máx: ${ruta.velocidadMaxima.toStringAsFixed(1)} km/h\n#SUPReady');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WithForegroundTask(
    child: Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      body: SafeArea(
          child: _state.activo ? _buildActivo() : _buildInicio()),
    ),
  );

  // ── Vista inicio ─────────────────────────────────────────
  Widget _buildInicio() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.surfing, size: 80, color: SupColors.cyanNeon),
      const SizedBox(height: 32),
      const Text('SUPReady', style: SupTextStyles.heading1),
      const SizedBox(height: 8),
      const Text('Iniciá tu remada', style: SupTextStyles.body),
      const SizedBox(height: 48),
      ElevatedButton.icon(
        onPressed: _cargando ? null : _iniciarTracking,
        icon: _cargando
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: SupColors.backgroundDeep, strokeWidth: 2))
            : const Icon(Icons.play_arrow_rounded),
        label: Text(_cargando ? 'OBTENIENDO GPS...' : 'INICIAR REMADA'),
        style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 68),
            textStyle: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700))),
    ]),
  );

  // ── Vista activa ──────────────────────────────────────────
  Widget _buildActivo() {
    final m = _state.metricas;
    final puntos = _svc.puntosGPS;
    final posActual = m != null ? LatLng(m.latitud, m.longitud) : null;

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: SupColors.surface,
        child: Row(children: [
          FadeTransition(opacity: _pulsoAnim,
              child: const Icon(Icons.fiber_manual_record,
                  color: SupColors.sosRed, size: 14)),
          const SizedBox(width: 8),
          const Text('GRABANDO', style: SupTextStyles.label),
          const Spacer(),
          // Toggle stats
          GestureDetector(
            onTap: () => setState(() => _mostrarStats = !_mostrarStats),
            child: Icon(_mostrarStats ? Icons.bar_chart : Icons.bar_chart_outlined,
                color: SupColors.cyanNeon, size: 20)),
          const SizedBox(width: 12),
          Text('${puntos.length} pts',
              style: SupTextStyles.body.copyWith(fontSize: 12)),
        ]),
      ),

      // Mapa con ruta coloreada
      Expanded(
        flex: 3,
        child: GestureDetector(
          onTap: () => setState(() => _mapSiguePosicion = false),
          child: Stack(children: [
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                  initialCenter: posActual ?? const LatLng(-38.0, -57.5),
                  initialZoom: 15),
              children: [
                TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.supready.app'),
                // Ruta coloreada por tramos de velocidad
                if (puntos.length >= 2)
                  PolylineLayer(polylines: _buildPolylines(puntos)),
                // Punto de inicio (verde)
                if (puntos.isNotEmpty)
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(puntos.first.latitud, puntos.first.longitud),
                      width: 16, height: 16,
                      child: Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SupColors.semaforoVerde,
                              border: Border.all(color: Colors.white, width: 2)))),
                  ]),
                // Posición actual (cyan pulsante)
                if (posActual != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: posActual,
                      width: 24, height: 24,
                      child: Container(decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SupColors.cyanNeon,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                            color: SupColors.cyanNeon.withOpacity(0.5),
                            blurRadius: 8)]))),
                  ]),
              ],
            ),
            // Botón re-centrar
            if (!_mapSiguePosicion)
              Positioned(top: 12, right: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _mapSiguePosicion = true);
                    if (posActual != null) _mapCtrl.move(posActual, 15);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: SupColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SupColors.cyanNeon)),
                    child: const Icon(Icons.my_location,
                        color: SupColors.cyanNeon, size: 20)))),
            // Leyenda de velocidad
            Positioned(top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: SupColors.backgroundDeep.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  _leyendaTramo(SupColors.semaforoVerde, '<5'),
                  const SizedBox(width: 8),
                  _leyendaTramo(SupColors.semaforoAmarillo, '5-12'),
                  const SizedBox(width: 8),
                  _leyendaTramo(SupColors.semaforoRojo, '>12'),
                  const SizedBox(width: 4),
                  const Text('km/h', style: TextStyle(
                      color: SupColors.textSecondary, fontSize: 9,
                      fontFamily: 'SpaceGrotesk')),
                ]))),
            // Métricas principales
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [SupColors.backgroundDeep,
                             SupColors.backgroundDeep.withOpacity(0)])),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _mini('DIST', m?.distanciaFormateada ?? '0.00 km'),
                    _mini('VEL', m?.velocidadFormateada ?? '0.0 km/h'),
                    _mini('TIEMPO', m?.duracionFormateada ?? '0m'),
                  ]),
                  if (_mostrarStats && m != null) ...[
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _mini('VEL MÁX', '${m.velocidadMaximaKmh.toStringAsFixed(1)} km/h'),
                      _mini('PUNTOS', '${puntos.length}'),
                      _mini('TRAMO', _labelTramo(m.tramo)),
                    ]),
                  ],
                ]))),
          ]),
        ),
      ),

      // Botón finalizar (long press)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: _buildBotonFinalizar()),
    ]);
  }

  Widget _leyendaTramo(Color color, String label) => Row(children: [
    Container(width: 16, height: 4,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(color: color,
        fontFamily: 'JetBrainsMono', fontSize: 9, fontWeight: FontWeight.w700)),
  ]);

  Widget _mini(String label, String valor) => Column(children: [
    Text(label, style: SupTextStyles.label.copyWith(fontSize: 10)),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 16)),
  ]);

  String _labelTramo(TramoVelocidad t) {
    switch (t) {
      case TramoVelocidad.lento:  return 'LENTO';
      case TramoVelocidad.medio:  return 'MEDIO';
      case TramoVelocidad.rapido: return 'RÁPIDO';
    }
  }

  Widget _buildBotonFinalizar() => GestureDetector(
    onLongPressStart: (_) {
      setState(() => _longPressActivo = true);
      _longPressCtrl.forward();
    },
    onLongPressEnd: (_) {
      if (_longPressCtrl.status != AnimationStatus.completed) {
        _longPressCtrl.reset();
        setState(() => _longPressActivo = false);
      }
    },
    child: AnimatedBuilder(
      animation: _longPressCtrl,
      builder: (_, __) => Stack(alignment: Alignment.center, children: [
        Container(height: 64,
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SupColors.divider)),
          alignment: Alignment.center,
          child: const Text('MANTENER PARA FINALIZAR',
              style: TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700, fontSize: 15,
                  color: SupColors.textSecondary, letterSpacing: 1))),
        if (_longPressActivo)
          ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Align(alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: _longPressCtrl.value,
                child: Container(height: 64,
                    color: SupColors.semaforoRojo.withOpacity(0.3))))),
      ]),
    ),
  );
}

// ─── Resumen post-remada con mapa coloreado ─────────────────
class _ResumenRutaSheet extends StatelessWidget {
  final RutaTrazadaModel ruta;
  final List<PuntoGPS> puntos;
  final VoidCallback onCompartir;
  const _ResumenRutaSheet({
      required this.ruta, required this.puntos, required this.onCompartir});

  Color _colorTramo(TramoVelocidad t) {
    switch (t) {
      case TramoVelocidad.lento:  return SupColors.semaforoVerde;
      case TramoVelocidad.medio:  return SupColors.semaforoAmarillo;
      case TramoVelocidad.rapido: return SupColors.semaforoRojo;
    }
  }

  List<Polyline> _polylines() {
    if (puntos.length < 2) return [];
    return List.generate(puntos.length - 1, (i) => Polyline(
      points: [
        LatLng(puntos[i].latitud, puntos[i].longitud),
        LatLng(puntos[i+1].latitud, puntos[i+1].longitud),
      ],
      color: _colorTramo(puntos[i].tramo),
      strokeWidth: 4,
    ));
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.5,
    expand: false,
    builder: (_, scroll) => ListView(controller: scroll,
        padding: const EdgeInsets.all(24), children: [
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: SupColors.divider,
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      const Text('Remada completada 🏄', style: SupTextStyles.heading2),
      const SizedBox(height: 16),
      // Mapa con ruta coloreada
      if (puntos.length >= 2)
        Container(height: 220,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SupColors.divider)),
          clipBehavior: Clip.hardEdge,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                  puntos[puntos.length ~/ 2].latitud,
                  puntos[puntos.length ~/ 2].longitud),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom)),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.supready.app'),
              PolylineLayer(polylines: _polylines()),
              MarkerLayer(markers: [
                Marker(point: LatLng(puntos.first.latitud, puntos.first.longitud),
                    width: 16, height: 16,
                    child: Container(decoration: BoxDecoration(
                        shape: BoxShape.circle, color: SupColors.semaforoVerde,
                        border: Border.all(color: Colors.white, width: 2)))),
                Marker(point: LatLng(puntos.last.latitud, puntos.last.longitud),
                    width: 16, height: 16,
                    child: Container(decoration: BoxDecoration(
                        shape: BoxShape.circle, color: SupColors.semaforoRojo,
                        border: Border.all(color: Colors.white, width: 2)))),
              ]),
            ])),
      const SizedBox(height: 12),
      // Leyenda
      Row(children: [
        _ley(SupColors.semaforoVerde, 'Lento <5 km/h'),
        const SizedBox(width: 16),
        _ley(SupColors.semaforoAmarillo, 'Medio 5-12'),
        const SizedBox(width: 16),
        _ley(SupColors.semaforoRojo, 'Rápido >12'),
      ]),
      const SizedBox(height: 16),
      // Stats
      _stat('Distancia', '${ruta.distanciaKm.toStringAsFixed(2)} km'),
      _stat('Duración', '${ruta.duracionMinutos} min'),
      _stat('Vel. media', '${ruta.velocidadMedia.toStringAsFixed(1)} km/h'),
      _stat('Vel. máxima', '${ruta.velocidadMaxima.toStringAsFixed(1)} km/h'),
      _stat('Puntos GPS', '${puntos.length}'),
      const SizedBox(height: 8),
      const Text('💾 Guardada en tu dispositivo',
          style: TextStyle(color: SupColors.cyanNeon,
              fontSize: 13, fontFamily: 'SpaceGrotesk')),
      const SizedBox(height: 20),
      OutlinedButton.icon(
          onPressed: onCompartir,
          icon: const Icon(Icons.share_outlined),
          label: const Text('COMPARTIR RESULTADO'),
          style: OutlinedButton.styleFrom(
              foregroundColor: SupColors.cyanNeon,
              side: const BorderSide(color: SupColors.cyanNeon),
              minimumSize: const Size(double.infinity, 52))),
      const SizedBox(height: 12),
      ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CERRAR')),
    ]),
  );

  Widget _ley(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 20, height: 4,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: c, fontSize: 10, fontFamily: 'SpaceGrotesk')),
  ]);

  Widget _stat(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: SupTextStyles.body),
      Text(valor, style: const TextStyle(color: SupColors.textPrimary,
          fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 16)),
    ]));
}
