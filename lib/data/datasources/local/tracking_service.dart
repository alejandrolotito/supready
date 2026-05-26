import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/models.dart';
import 'sup_database.dart';

// ============================================================
// SUPReady v3.8 - Servicio de Trackeo GPS con Foreground Service
//
// PROBLEMA RESUELTO: Al cambiar de pestaña o minimizar la app,
// Android mataba el proceso y perdía la navegación.
//
// SOLUCIÓN: ForegroundService de Android con notificación
// persistente "Remada en curso — X km". El SO no puede matar
// un proceso con un ForegroundService activo.
// ============================================================

enum EstadoTracking { inactivo, activo, pausado, finalizado }

class TrackingService with WidgetsBindingObserver {
  static final TrackingService instance = TrackingService._();
  TrackingService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  EstadoTracking _estado = EstadoTracking.inactivo;
  int? _rutaId;
  int _usuarioId = 0, _spotId = 0;
  int _secuencia = 0;
  double _distanciaKm = 0.0, _velMax = 0.0;
  DateTime? _inicio;
  Position? _ultimaPos;
  DateTime? _ultimaVariacion;
  DateTime? _backgroundAt;
  bool _enBackground = false;

  final _estadoCtrl   = StreamController<EstadoTracking>.broadcast();
  final _coordCtrl    = StreamController<CoordenadasRutaModel>.broadcast();
  final _metricasCtrl = StreamController<MetricasTracking>.broadcast();
  final _sosCtrl      = StreamController<void>.broadcast();

  Stream<EstadoTracking>       get estadoStream    => _estadoCtrl.stream;
  Stream<CoordenadasRutaModel> get coordenadaStream => _coordCtrl.stream;
  Stream<MetricasTracking>     get metricasStream   => _metricasCtrl.stream;
  Stream<void>                 get sosStream        => _sosCtrl.stream;

  StreamSubscription<Position>? _gpsSub;
  Timer? _sosTimer;
  Timer? _notifTimer;

  EstadoTracking get estado => _estado;
  bool get activo => _estado == EstadoTracking.activo;

  // ─── Lifecycle: pausa SOS en background ─────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!activo) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _enBackground = true;
      _backgroundAt = DateTime.now();
      _sosTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_enBackground) {
        _enBackground = false;
        if (_backgroundAt != null && _ultimaVariacion != null) {
          final fuera = DateTime.now().difference(_backgroundAt!);
          _ultimaVariacion = _ultimaVariacion!.add(fuera);
        }
        _backgroundAt = null;
        if (_estado == EstadoTracking.activo) _iniciarSOS();
      }
    }
  }

  // ─── INICIAR ─────────────────────────────────────────────
  Future<bool> iniciarTracking({
    required int usuarioId,
    required int spotId,
  }) async {
    if (!await _checkPermisos()) return false;

    // Iniciar Foreground Service ANTES de empezar el GPS
    await _iniciarForegroundService();

    _usuarioId = usuarioId;
    _spotId = spotId;
    _estado = EstadoTracking.activo;
    _inicio = DateTime.now();
    _secuencia = 0;
    _distanciaKm = 0.0;
    _velMax = 0.0;
    _ultimaVariacion = DateTime.now();
    _enBackground = false;

    final ruta = RutaTrazadaModel(
        usuarioId: usuarioId, spotId: spotId, iniciadaEn: _inicio!);
    _rutaId = await SupDatabase.instance.insertarRuta(ruta);

    _estadoCtrl.add(_estado);
    _iniciarGPS();
    _iniciarSOS();
    _iniciarActualizacionNotif();
    return true;
  }

  // ─── FINALIZAR ───────────────────────────────────────────
  Future<RutaTrazadaModel?> finalizarTracking() async {
    if (_rutaId == null || _estado != EstadoTracking.activo) return null;

    _gpsSub?.cancel();
    _sosTimer?.cancel();
    _notifTimer?.cancel();

    // Apagar Foreground Service
    await FlutterForegroundTask.stopService();

    _estado = EstadoTracking.finalizado;

    final duracion = _inicio != null
        ? DateTime.now().difference(_inicio!).inMinutes
        : 0;
    final velMedia =
        duracion > 0 ? _distanciaKm / (duracion / 60) : 0.0;

    final ruta = RutaTrazadaModel(
      rutaId: _rutaId,
      usuarioId: _usuarioId,
      spotId: _spotId,
      iniciadaEn: _inicio!,
      finalizadaEn: DateTime.now(),
      distanciaKm: _distanciaKm,
      duracionMinutos: duracion,
      velocidadMedia: velMedia,
      velocidadMaxima: _velMax,
    );
    await SupDatabase.instance.actualizarRuta(ruta);
    _estadoCtrl.add(_estado);
    return ruta;
  }

  void confirmarEstoyBien() {
    if (_estado != EstadoTracking.activo) return;
    _ultimaVariacion = DateTime.now();
    _sosTimer?.cancel();
    _iniciarSOS();
  }

  // ─── Foreground Service ───────────────────────────────────
  Future<void> _iniciarForegroundService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'supready_tracking',
        channelName: 'SUPReady — Remada activa',
        channelDescription: 'Notificación mientras la remada está en curso.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: '🏄 Remada en curso',
      notificationText: 'GPS activo — 0.00 km recorridos',
      callback: _foregroundCallback,
    );
  }

  // Actualiza la notificación cada 5 segundos con distancia real
  void _iniciarActualizacionNotif() {
    _notifTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!activo) return;
      FlutterForegroundTask.updateService(
        notificationTitle: '🏄 Remada en curso',
        notificationText:
            '${_distanciaKm.toStringAsFixed(2)} km · ${_duracionStr()}',
      );
    });
  }

  String _duracionStr() {
    if (_inicio == null) return '0m';
    final min = DateTime.now().difference(_inicio!).inMinutes;
    final h = min ~/ 60;
    final m = min % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  // ─── GPS ─────────────────────────────────────────────────
  void _iniciarGPS() {
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen(_procesarPos);
  }

  void _procesarPos(Position pos) async {
    if (_estado != EstadoTracking.activo || _rutaId == null) return;

    final velKmh = pos.speed * 3.6;
    if (velKmh > _velMax) _velMax = velKmh;

    if (_ultimaPos != null) {
      final dist = _haversine(
        _ultimaPos!.latitude, _ultimaPos!.longitude,
        pos.latitude, pos.longitude,
      );
      if (dist > 0.002) {
        _distanciaKm += dist;
        _ultimaVariacion = DateTime.now();
      }
    }

    final coord = CoordenadasRutaModel(
      rutaId: _rutaId!,
      latitud: pos.latitude,
      longitud: pos.longitude,
      secuencia: _secuencia++,
      velocidadKmh: velKmh,
      timestamp: DateTime.now(),
    );
    await SupDatabase.instance.insertarCoordenada(coord);
    _coordCtrl.add(coord);

    final duracion = _inicio != null
        ? DateTime.now().difference(_inicio!).inMinutes
        : 0;
    _metricasCtrl.add(MetricasTracking(
      distanciaKm: _distanciaKm,
      velocidadActualKmh: velKmh,
      velocidadMaximaKmh: _velMax,
      duracionMinutos: duracion,
      latitud: pos.latitude,
      longitud: pos.longitude,
    ));
    _ultimaPos = pos;
  }

  // ─── Timer SOS ───────────────────────────────────────────
  void _iniciarSOS() {
    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_enBackground || _ultimaVariacion == null) return;
      if (DateTime.now().difference(_ultimaVariacion!).inMinutes >= 15) {
        _sosCtrl.add(null);
        _sosTimer?.cancel();
      }
    });
  }

  double _haversine(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  Future<bool> _checkPermisos() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p != LocationPermission.denied &&
        p != LocationPermission.deniedForever;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsSub?.cancel();
    _sosTimer?.cancel();
    _notifTimer?.cancel();
    _estadoCtrl.close();
    _coordCtrl.close();
    _metricasCtrl.close();
    _sosCtrl.close();
  }
}

// Callback para el Foreground Task (se ejecuta en isolate separado)
@pragma('vm:entry-point')
void _foregroundCallback() {
  FlutterForegroundTask.setTaskHandler(_TrackingTaskHandler());
}

class _TrackingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // El timer de actualización de la notificación lo maneja _notifTimer
    // Este handler es requerido por la API pero la lógica real está en TrackingService
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

// ─── DTO de métricas ─────────────────────────────────────────
class MetricasTracking {
  final double distanciaKm, velocidadActualKmh, velocidadMaximaKmh;
  final int duracionMinutos;
  final double latitud, longitud;

  const MetricasTracking({
    required this.distanciaKm,
    required this.velocidadActualKmh,
    required this.velocidadMaximaKmh,
    required this.duracionMinutos,
    required this.latitud,
    required this.longitud,
  });

  String get distanciaFormateada =>
      '${distanciaKm.toStringAsFixed(2)} km';
  String get velocidadFormateada =>
      '${velocidadActualKmh.toStringAsFixed(1)} km/h';
  String get duracionFormateada {
    final h = duracionMinutos ~/ 60;
    final m = duracionMinutos % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
