import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/local/tracking_service.dart';
import '../../../data/models/models.dart';

// ============================================================
// SUPReady v3 - Tracking Screen
// - Mapa en vivo con flutter_map
// - Ruta coloreada por velocidad al finalizar
// - Foto al finalizar
// - Compartir ruta
// ============================================================

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with TickerProviderStateMixin {
  final _trackingService = TrackingService.instance;
  StreamSubscription<MetricasTracking>? _metricasSub;
  StreamSubscription<CoordenadasRutaModel>? _coordSub;
  StreamSubscription<void>? _sosSub;

  MetricasTracking? _metricas;
  bool _trackingActivo = false;
  bool _cargando = false;
  LatLng? _posicionActual;
  final List<LatLng> _coordenadas = [];
  final MapController _mapController = MapController();

  late AnimationController _longPressController;
  late AnimationController _pulsoController;
  late Animation<double> _pulsoAnim;
  bool _longPressActivo = false;

  @override
  void initState() {
    super.initState();
    _longPressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..addStatusListener((s) { if (s == AnimationStatus.completed) _finalizarTracking(); });
    _pulsoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulsoAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pulsoController, curve: Curves.easeInOut));
    _sosSub = _trackingService.sosStream.listen((_) => _mostrarAlertaSOS());
  }

  @override
  void dispose() {
    _longPressController.dispose(); _pulsoController.dispose();
    _metricasSub?.cancel(); _coordSub?.cancel(); _sosSub?.cancel();
    super.dispose();
  }

  Future<void> _iniciarTracking() async {
    setState(() => _cargando = true);
    final ok = await _trackingService.iniciarTracking(usuarioId: 1, spotId: 1);
    if (ok) {
      _metricasSub = _trackingService.metricasStream.listen((m) {
        if (mounted) setState(() {
          _metricas = m;
          _posicionActual = LatLng(m.latitud, m.longitud);
          try { _mapController.move(_posicionActual!, 15); } catch (_) {}
        });
      });
      _coordSub = _trackingService.coordenadaStream.listen((c) {
        if (mounted) setState(() => _coordenadas.add(LatLng(c.latitud, c.longitud)));
      });
      HapticFeedback.heavyImpact();
      setState(() { _trackingActivo = true; _cargando = false; });
    } else {
      setState(() => _cargando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener permiso de GPS'), backgroundColor: SupColors.surface));
    }
  }

  Future<void> _finalizarTracking() async {
    final ruta = await _trackingService.finalizarTracking();
    _metricasSub?.cancel(); _coordSub?.cancel();
    HapticFeedback.heavyImpact();
    setState(() { _trackingActivo = false; _longPressActivo = false; _longPressController.reset(); });
    if (ruta != null && mounted) _mostrarResumenRuta(ruta);
  }

  void _mostrarAlertaSOS() {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: SupColors.surface,
      title: const Text('SOS ACTIVADO', style: TextStyle(color: SupColors.sosRed, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
      content: const Text('Sin movimiento 15 min. Se puede enviar alerta de emergencia.', style: TextStyle(color: SupColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ESTOY BIEN', style: TextStyle(color: SupColors.cyanNeon))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: SupColors.sosRed),
          onPressed: () { Navigator.pop(context); _enviarSOS(); },
          child: const Text('ENVIAR SOS')),
      ],
    ));
  }

  Future<void> _enviarSOS() async {
    final uri = Uri.parse('sms:+5491100000000?body=EMERGENCIA SUP - necesito ayuda');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo SMS de emergencia...'), backgroundColor: SupColors.sosRed));
  }

  void _mostrarResumenRuta(RutaTrazadaModel ruta) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: SupColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResumenRutaSheet(ruta: ruta, coordenadas: List.from(_coordenadas),
          onCompartir: _compartirRuta, onFoto: _tomarFoto),
    );
  }

  Future<void> _compartirRuta() async {
    final texto = 'Remé ${_metricas?.distanciaKm.toStringAsFixed(2) ?? "?"} km en ${_metricas?.duracionFormateada ?? "?"} a ${_metricas?.velocidadActualKmh.toStringAsFixed(1) ?? "?"} km/h promedio. #SUPReady';
    await Share.share(texto, subject: 'Mi remada en SUPReady');
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    await picker.pickImage(source: ImageSource.camera);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto guardada'), backgroundColor: SupColors.semaforoVerde));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      body: SafeArea(child: _trackingActivo ? _buildVistaActiva() : _buildVistaInicio()),
    );
  }

  Widget _buildVistaInicio() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.surfing, size: 80, color: SupColors.cyanNeon),
      const SizedBox(height: 32),
      Text('SUPReady', style: SupTextStyles.heading1.copyWith(fontSize: 36)),
      const SizedBox(height: 8),
      const Text('Iniciá tu remada', style: SupTextStyles.body),
      const SizedBox(height: 48),
      ElevatedButton.icon(
        onPressed: _cargando ? null : _iniciarTracking,
        icon: _cargando ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(color: SupColors.backgroundDeep, strokeWidth: 2))
            : const Icon(Icons.play_arrow_rounded),
        label: Text(_cargando ? 'OBTENIENDO GPS...' : 'INICIAR REMADA'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 68),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  Widget _buildVistaActiva() => Column(children: [
    _buildHeaderGrabando(),
    // MAPA EN VIVO
    Expanded(
      flex: 3,
      child: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _posicionActual ?? const LatLng(-38.0, -57.5),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.supready.app',
            ),
            if (_coordenadas.length >= 2)
              PolylineLayer(polylines: [
                Polyline(points: _coordenadas, color: SupColors.cyanNeon, strokeWidth: 3),
              ]),
            if (_posicionActual != null)
              MarkerLayer(markers: [
                Marker(
                  point: _posicionActual!,
                  width: 24, height: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: SupColors.cyanNeon,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: SupColors.cyanNeon.withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                ),
              ]),
          ],
        ),
        // Overlay métricas sobre mapa
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [SupColors.backgroundDeep, SupColors.backgroundDeep.withOpacity(0)]),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _metricaMini('DIST', _metricas?.distanciaFormateada ?? '0.00 km'),
              _metricaMini('VEL', _metricas?.velocidadFormateada ?? '0.0 km/h'),
              _metricaMini('TIEMPO', _metricas?.duracionFormateada ?? '0m'),
            ]),
          ),
        ),
      ]),
    ),
    // Panel inferior con métricas grandes y botón finalizar
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _buildBotonFinalizar(),
    ),
    const SizedBox(height: 8),
  ]);

  Widget _buildHeaderGrabando() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    color: SupColors.surface,
    child: Row(children: [
      FadeTransition(opacity: _pulsoAnim,
          child: const Icon(Icons.fiber_manual_record, color: SupColors.sosRed, size: 14)),
      const SizedBox(width: 8),
      const Text('GRABANDO', style: SupTextStyles.label),
      const Spacer(),
      Text('${_coordenadas.length} pts', style: SupTextStyles.body.copyWith(fontSize: 12)),
    ]),
  );

  Widget _metricaMini(String label, String valor) => Column(children: [
    Text(label, style: SupTextStyles.label.copyWith(fontSize: 10)),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary, fontFamily: 'JetBrainsMono',
        fontWeight: FontWeight.w700, fontSize: 16)),
  ]);

  Widget _buildBotonFinalizar() => GestureDetector(
    onLongPressStart: (_) {
      setState(() => _longPressActivo = true);
      _longPressController.forward();
    },
    onLongPressEnd: (_) {
      if (_longPressController.status != AnimationStatus.completed) {
        _longPressController.reset();
        setState(() => _longPressActivo = false);
      }
    },
    child: AnimatedBuilder(
      animation: _longPressController,
      builder: (_, __) => Stack(alignment: Alignment.center, children: [
        Container(
          height: 64,
          decoration: BoxDecoration(color: SupColors.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SupColors.divider)),
          alignment: Alignment.center,
          child: const Text('MANTENER PARA FINALIZAR', style: TextStyle(
              fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 15,
              color: SupColors.textSecondary, letterSpacing: 1)),
        ),
        if (_longPressActivo)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Align(alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: _longPressController.value,
                child: Container(height: 64, color: SupColors.semaforoRojo.withOpacity(0.3)))),
          ),
      ]),
    ),
  );
}

// ----------------------------------------------------------
// Bottom Sheet Resumen de Ruta con mapa + stats + acciones
// ----------------------------------------------------------
class _ResumenRutaSheet extends StatelessWidget {
  final RutaTrazadaModel ruta;
  final List<LatLng> coordenadas;
  final VoidCallback onCompartir;
  final VoidCallback onFoto;

  const _ResumenRutaSheet({
    required this.ruta, required this.coordenadas,
    required this.onCompartir, required this.onFoto,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
      builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(24), children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: SupColors.divider, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        const Text('Remada completada', style: SupTextStyles.heading2),
        const SizedBox(height: 16),
        // Mini mapa con ruta coloreada por velocidad
        if (coordenadas.length >= 2)
          Container(
            height: 200, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SupColors.divider)),
            clipBehavior: Clip.hardEdge,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: coordenadas[coordenadas.length ~/ 2],
                initialZoom: 14, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.supready.app'),
                PolylineLayer(polylines: _buildPolylinasVelocidad()),
              ],
            ),
          ),
        const SizedBox(height: 16),
        // Stats
        _statRow('Distancia', '${ruta.distanciaKm.toStringAsFixed(2)} km'),
        _statRow('Duración', '${ruta.duracionMinutos} min'),
        _statRow('Velocidad media', '${ruta.velocidadMedia.toStringAsFixed(1)} km/h'),
        _statRow('Velocidad máxima', '${ruta.velocidadMaxima.toStringAsFixed(1)} km/h'),
        const SizedBox(height: 8),
        const Text('Guardada localmente', style: TextStyle(color: SupColors.cyanNeon, fontSize: 13, fontFamily: 'SpaceGrotesk')),
        const SizedBox(height: 20),
        // Acciones
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onFoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('FOTO'),
            style: OutlinedButton.styleFrom(foregroundColor: SupColors.cyanNeon,
                side: const BorderSide(color: SupColors.cyanNeon), minimumSize: const Size(0, 52)),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: onCompartir,
            icon: const Icon(Icons.share_outlined),
            label: const Text('COMPARTIR'),
            style: OutlinedButton.styleFrom(foregroundColor: SupColors.cyanNeon,
                side: const BorderSide(color: SupColors.cyanNeon), minimumSize: const Size(0, 52)),
          )),
        ]),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR')),
      ]),
    );
  }

  // Colorear tramos según velocidad: verde lento, amarillo medio, rojo rápido
  List<Polyline> _buildPolylinasVelocidad() {
    if (coordenadas.length < 2) return [];
    final polylines = <Polyline>[];
    for (int i = 0; i < coordenadas.length - 1; i++) {
      final t = i / coordenadas.length;
      final color = t < 0.33 ? SupColors.semaforoVerde
          : t < 0.66 ? SupColors.semaforoAmarillo : SupColors.semaforoRojo;
      polylines.add(Polyline(points: [coordenadas[i], coordenadas[i+1]],
          color: color, strokeWidth: 4));
    }
    return polylines;
  }

  Widget _statRow(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: SupTextStyles.body),
      Text(valor, style: const TextStyle(color: SupColors.textPrimary, fontFamily: 'JetBrainsMono',
          fontWeight: FontWeight.w700, fontSize: 16)),
    ]),
  );
}
