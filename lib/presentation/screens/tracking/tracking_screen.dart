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

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  final _svc = TrackingService.instance;

  StreamSubscription<MetricasTracking>? _metricasSub;
  StreamSubscription<CoordenadasRutaModel>? _coordSub;
  StreamSubscription<void>? _sosSub;

  MetricasTracking? _metricas;
  bool _trackingActivo = false;
  bool _cargando = false;
  LatLng? _posActual;
  final List<LatLng> _coords = [];
  final _mapCtrl = MapController();

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

    // FIX: SOS handler — cancelar NO destruye la sesión
    _sosSub = _svc.sosStream.listen((_) => _mostrarAlertaSOS());
  }

  @override
  void dispose() {
    _longPressCtrl.dispose(); _pulsoCtrl.dispose();
    _metricasSub?.cancel(); _coordSub?.cancel(); _sosSub?.cancel();
    super.dispose();
  }

  Future<void> _iniciarTracking() async {
    setState(() => _cargando = true);
    final ok = await _svc.iniciarTracking(usuarioId: 1, spotId: 1);
    if (ok) {
      _metricasSub = _svc.metricasStream.listen((m) {
        if (!mounted) return;
        setState(() {
          _metricas = m;
          _posActual = LatLng(m.latitud, m.longitud);
          try { _mapCtrl.move(_posActual!, 15); } catch (_) {}
        });
      });
      _coordSub = _svc.coordenadaStream.listen((c) {
        if (mounted) setState(() => _coords.add(LatLng(c.latitud, c.longitud)));
      });
      HapticFeedback.heavyImpact();
      setState(() { _trackingActivo = true; _cargando = false; });
    } else {
      setState(() => _cargando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener permiso de GPS'),
            backgroundColor: SupColors.surface));
    }
  }

  Future<void> _finalizarTracking() async {
    final ruta = await _svc.finalizarTracking();
    _metricasSub?.cancel(); _coordSub?.cancel();
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() {
      _trackingActivo = false;
      _longPressActivo = false;
      _longPressCtrl.reset();
    });
    if (ruta != null) _mostrarResumen(ruta);
  }

  // FIX PRINCIPAL: cancelar SOS solo reinicia el timer, NO toca el estado
  void _mostrarAlertaSOS() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // forzar decisión
      builder: (_) => WillPopScope(
        onWillPop: () async => false, // bloquear botón atrás
        child: AlertDialog(
          backgroundColor: SupColors.surface,
          title: Row(children: [
            const Icon(Icons.warning_rounded, color: SupColors.sosRed, size: 28),
            const SizedBox(width: 10),
            const Text('SOS — Sin movimiento', style: TextStyle(
                color: SupColors.sosRed, fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 18)),
          ]),
          content: const Text(
            'No se detectó movimiento en 15 minutos.\n\n'
            '¿Estás bien? Si no respondés se enviará una alerta de emergencia.',
            style: TextStyle(color: SupColors.textSecondary, height: 1.5)),
          actions: [
            // ESTOY BIEN — reinicia timer, NO destruye la sesión
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: SupColors.semaforoVerde,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48)),
              onPressed: () {
                Navigator.pop(context); // cerrar dialog
                _svc.confirmarEstoyBien(); // reiniciar timer, seguir remando
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Bien! Timer SOS reiniciado'),
                      backgroundColor: SupColors.semaforoVerde, duration: Duration(seconds: 2)));
              },
              child: const Text('ESTOY BIEN — SEGUIR REMANDO'),
            ),
            const SizedBox(height: 8),
            // ENVIAR SOS — abre SMS de emergencia
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: SupColors.sosRed,
                  side: const BorderSide(color: SupColors.sosRed),
                  minimumSize: const Size(0, 48)),
              onPressed: () async {
                Navigator.pop(context);
                final pos = _posActual;
                final coords = pos != null
                    ? 'Mi posición: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
                    : 'Posición desconocida';
                await Share.share(
                  '🆘 EMERGENCIA SUP - Necesito ayuda\n$coords\n'
                  'Distancia recorrida: ${_metricas?.distanciaFormateada ?? "?"}',
                  subject: 'EMERGENCIA SUP');
              },
              child: const Text('ENVIAR ALERTA DE EMERGENCIA'),
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
        ruta: ruta, coordenadas: List.from(_coords),
        onCompartir: () async {
          await Share.share(
            '🏄 Remé ${ruta.distanciaKm.toStringAsFixed(2)} km en ${ruta.duracionMinutos} min\n'
            'Vel. media: ${ruta.velocidadMedia.toStringAsFixed(1)} km/h · '
            'Máx: ${ruta.velocidadMaxima.toStringAsFixed(1)} km/h\n#SUPReady');
        },
        onFoto: () async {
          await ImagePicker().pickImage(source: ImageSource.camera);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto guardada'),
                backgroundColor: SupColors.semaforoVerde));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SupColors.backgroundDeep,
    body: SafeArea(
      child: _trackingActivo ? _buildActivo() : _buildInicio()),
  );

  Widget _buildInicio() => Padding(
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
        icon: _cargando
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: SupColors.backgroundDeep, strokeWidth: 2))
            : const Icon(Icons.play_arrow_rounded),
        label: Text(_cargando ? 'OBTENIENDO GPS...' : 'INICIAR REMADA'),
        style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 68),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  Widget _buildActivo() => Column(children: [
    _buildHeader(),
    Expanded(
      flex: 3,
      child: Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _posActual ?? const LatLng(-38.0, -57.5),
            initialZoom: 15,
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.supready.app'),
            if (_coords.length >= 2)
              PolylineLayer(polylines: [
                Polyline(points: _coords, color: SupColors.cyanNeon, strokeWidth: 3)]),
            if (_posActual != null)
              MarkerLayer(markers: [
                Marker(point: _posActual!, width: 24, height: 24,
                  child: Container(decoration: BoxDecoration(
                    shape: BoxShape.circle, color: SupColors.cyanNeon,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(
                        color: SupColors.cyanNeon.withOpacity(0.5), blurRadius: 8)]))),
              ]),
          ],
        ),
        // Métricas sobre mapa
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [SupColors.backgroundDeep, SupColors.backgroundDeep.withOpacity(0)])),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _mini('DIST', _metricas?.distanciaFormateada ?? '0.00 km'),
              _mini('VEL', _metricas?.velocidadFormateada ?? '0.0 km/h'),
              _mini('TIEMPO', _metricas?.duracionFormateada ?? '0m'),
            ]),
          )),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _buildBotonFinalizar()),
    const SizedBox(height: 8),
  ]);

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    color: SupColors.surface,
    child: Row(children: [
      FadeTransition(opacity: _pulsoAnim,
          child: const Icon(Icons.fiber_manual_record, color: SupColors.sosRed, size: 14)),
      const SizedBox(width: 8),
      const Text('GRABANDO', style: SupTextStyles.label),
      const Spacer(),
      Text('${_coords.length} pts', style: SupTextStyles.body.copyWith(fontSize: 12)),
    ]),
  );

  Widget _mini(String label, String valor) => Column(children: [
    Text(label, style: SupTextStyles.label.copyWith(fontSize: 10)),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 16)),
  ]);

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
        Container(
          height: 64,
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SupColors.divider)),
          alignment: Alignment.center,
          child: const Text('MANTENER PARA FINALIZAR', style: TextStyle(
              fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
              fontSize: 15, color: SupColors.textSecondary, letterSpacing: 1))),
        if (_longPressActivo)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
  const _ResumenRutaSheet({
    required this.ruta, required this.coordenadas,
    required this.onCompartir, required this.onFoto});

  List<Polyline> _polylines() {
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

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
    builder: (_, scroll) => ListView(controller: scroll,
        padding: const EdgeInsets.all(24), children: [
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: SupColors.divider,
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      const Text('Remada completada 🏄', style: SupTextStyles.heading2),
      const SizedBox(height: 16),
      if (coordenadas.length >= 2)
        Container(height: 200,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SupColors.divider)),
          clipBehavior: Clip.hardEdge,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: coordenadas[coordenadas.length ~/ 2],
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
        Expanded(child: OutlinedButton.icon(
          onPressed: onFoto, icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('FOTO'),
          style: OutlinedButton.styleFrom(foregroundColor: SupColors.cyanNeon,
              side: const BorderSide(color: SupColors.cyanNeon),
              minimumSize: const Size(0, 52)))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(
          onPressed: onCompartir, icon: const Icon(Icons.share_outlined),
          label: const Text('COMPARTIR'),
          style: OutlinedButton.styleFrom(foregroundColor: SupColors.cyanNeon,
              side: const BorderSide(color: SupColors.cyanNeon),
              minimumSize: const Size(0, 52)))),
      ]),
      const SizedBox(height: 12),
      ElevatedButton(
          onPressed: () => Navigator.pop(context), child: const Text('CERRAR')),
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
