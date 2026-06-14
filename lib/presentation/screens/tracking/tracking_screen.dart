import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/tracking_state.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/datasources/local/tracking_service.dart';
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
    _pulsoAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulsoCtrl, curve: Curves.easeInOut));
    _state.addListener(_onStateChanged);
    _sosSub = _svc.sosStream.listen((_) => _mostrarAlertaSOS());
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _longPressCtrl.dispose(); _pulsoCtrl.dispose();
    _sosSub?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
    final m = _state.metricas;
    if (m != null && _mapSiguePosicion) {
      try { _mapCtrl.move(LatLng(m.latitud, m.longitud), _mapCtrl.camera.zoom); } catch (_) {}
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
          content: Text('No se pudo obtener GPS'), backgroundColor: SupColors.surface));
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

  void _mostrarAlertaSOS() {
    if (!mounted) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: SupColors.surface,
          title: const Row(children: [
            Icon(Icons.warning_rounded, color: SupColors.sosRed, size: 26),
            SizedBox(width: 8),
            Flexible(child: Text('SOS — Sin movimiento',
                style: TextStyle(color: SupColors.sosRed, fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700, fontSize: 17))),
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
              child: const Text('ESTOY BIEN — SEGUIR REMANDO'),
            ),
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
                await Share.share('🆘 EMERGENCIA SUP\nPosición: $coords');
              },
              child: const Text('ENVIAR ALERTA'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarResumen(RutaTrazadaModel ruta) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: SupColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResumenRutaSheet(
        ruta: ruta,
        coordenadas: _state.coordenadas.map((c) => LatLng(c.latitud, c.longitud)).toList(),
        onCompartir: () async {
          await Share.share('🏄 Remé ${ruta.distanciaKm.toStringAsFixed(2)} km '
              'en ${ruta.duracionMinutos} min — ${ruta.velocidadMedia.toStringAsFixed(1)} km/h #SUPReady');
        },
        onFoto: () async {
          await ImagePicker().pickImage(source: ImageSource.camera);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Foto guardada'), backgroundColor: SupColors.semaforoVerde));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WithForegroundTask(
    child: Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      body: SafeArea(child: _state.activo ? _buildActivo() : _buildInicio()),
    ),
  );

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
        icon: _cargando ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(color: SupColors.backgroundDeep, strokeWidth: 2))
            : const Icon(Icons.play_arrow_rounded),
        label: Text(_cargando ? 'OBTENIENDO GPS...' : 'INICIAR REMADA'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 68),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  Widget _buildActivo() {
    final m = _state.metricas;
    final coords = _state.coordenadas.map((c) => LatLng(c.latitud, c.longitud)).toList();
    final pos = m != null ? LatLng(m.latitud, m.longitud) : null;
    return Column(children: [
      // Header grabando
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: SupColors.surface,
        child: Row(children: [
          FadeTransition(opacity: _pulsoAnim,
              child: const Icon(Icons.fiber_manual_record, color: SupColors.sosRed, size: 14)),
          const SizedBox(width: 8),
          const Text('GRABANDO', style: SupTextStyles.label),
          const Spacer(),
          Text('${_state.coordenadas.length} pts',
              style: SupTextStyles.body.copyWith(fontSize: 12)),
        ]),
      ),
      // Mapa
      Expanded(flex: 3, child: GestureDetector(
        onTap: () => setState(() => _mapSiguePosicion = false),
        child: Stack(children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
                initialCenter: pos ?? const LatLng(-38.0, -57.5),
                initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.supready.app'),
              if (coords.length >= 2) PolylineLayer(polylines: [
                Polyline(points: coords, color: SupColors.cyanNeon, strokeWidth: 3)]),
              if (pos != null) MarkerLayer(markers: [
                Marker(point: pos, width: 24, height: 24,
                  child: Container(decoration: BoxDecoration(
                    shape: BoxShape.circle, color: SupColors.cyanNeon,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(
                        color: SupColors.cyanNeon.withOpacity(0.5), blurRadius: 8)]))),
              ]),
            ],
          ),
          // Re-centrar mapa
          if (!_mapSiguePosicion)
            Positioned(top: 12, right: 12,
              child: GestureDetector(
                onTap: () { setState(() => _mapSiguePosicion = true);
                  if (pos != null) _mapCtrl.move(pos, 15); },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: SupColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SupColors.cyanNeon)),
                  child: const Icon(Icons.my_location, color: SupColors.cyanNeon, size: 20)))),
          // Métricas overlay
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [SupColors.backgroundDeep, SupColors.backgroundDeep.withOpacity(0)])),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _mini('DIST', m?.distanciaFormateada ?? '0.00 km'),
                _mini('VEL', m?.velocidadFormateada ?? '0.0 km/h'),
                _mini('TIEMPO', m?.duracionFormateada ?? '0m'),
              ]))),
        ]),
      )),
      // Botón finalizar
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _buildBotonFinalizar()),
      const SizedBox(height: 8),
    ]);
  }

  Widget _mini(String label, String valor) => Column(children: [
    Text(label, style: SupTextStyles.label.copyWith(fontSize: 10)),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 16)),
  ]);

  Widget _buildBotonFinalizar() => GestureDetector(
    onLongPressStart: (_) { setState(() => _longPressActivo = true); _longPressCtrl.forward(); },
    onLongPressEnd: (_) {
      if (_longPressCtrl.status != AnimationStatus.completed) {
        _longPressCtrl.reset(); setState(() => _longPressActivo = false);
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
          child: const Text('MANTENER PARA FINALIZAR', style: TextStyle(
              fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
              fontSize: 15, color: SupColors.textSecondary, letterSpacing: 1))),
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

class _ResumenRutaSheet extends StatelessWidget {
  final RutaTrazadaModel ruta;
  final List<LatLng> coordenadas;
  final VoidCallback onCompartir, onFoto;
  const _ResumenRutaSheet({required this.ruta, required this.coordenadas,
      required this.onCompartir, required this.onFoto});

  List<Polyline> _polylines() {
    if (coordenadas.length < 2) return [];
    return List.generate(coordenadas.length - 1, (i) {
      final t = i / coordenadas.length;
      return Polyline(points: [coordenadas[i], coordenadas[i+1]],
          color: t < 0.33 ? SupColors.semaforoVerde
              : t < 0.66 ? SupColors.semaforoAmarillo : SupColors.semaforoRojo,
          strokeWidth: 4);
    });
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
    builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(24), children: [
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: SupColors.divider, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      const Text('Remada completada 🏄', style: SupTextStyles.heading2),
      const SizedBox(height: 16),
      if (coordenadas.length >= 2)
        Container(height: 200,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SupColors.divider)),
          clipBehavior: Clip.hardEdge,
          child: FlutterMap(
            options: MapOptions(initialCenter: coordenadas[coordenadas.length ~/ 2],
                initialZoom: 14,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.supready.app'),
              PolylineLayer(polylines: _polylines()),
            ])),
      const SizedBox(height: 16),
      _stat('Distancia', '${ruta.distanciaKm.toStringAsFixed(2)} km'),
      _stat('Duración', '${ruta.duracionMinutos} min'),
      _stat('Velocidad media', '${ruta.velocidadMedia.toStringAsFixed(1)} km/h'),
      _stat('Velocidad máxima', '${ruta.velocidadMaxima.toStringAsFixed(1)} km/h'),
      const SizedBox(height: 8),
      const Text('💾 Guardada localmente', style: TextStyle(
          color: SupColors.cyanNeon, fontSize: 13, fontFamily: 'SpaceGrotesk')),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: onFoto,
            icon: const Icon(Icons.camera_alt_outlined), label: const Text('FOTO'),
            style: OutlinedButton.styleFrom(foregroundColor: SupColors.cyanNeon,
                side: const BorderSide(color: SupColors.cyanNeon), minimumSize: const Size(0, 52)))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(onPressed: onCompartir,
            icon: const Icon(Icons.share_outlined), label: const Text('COMPARTIR'),
            style: OutlinedButton.styleFrom(foregroundColor: SupColors.cyanNeon,
                side: const BorderSide(color: SupColors.cyanNeon), minimumSize: const Size(0, 52)))),
      ]),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR')),
    ]),
  );

  Widget _stat(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: SupTextStyles.body),
      Text(valor, style: const TextStyle(color: SupColors.textPrimary,
          fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 16)),
    ]),
  );
}
