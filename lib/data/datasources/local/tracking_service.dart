import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/models.dart';
import 'sup_database.dart';

// ============================================================
// SUPReady v2.0 - Tracking conforme a specs
// - distanceFilter: 2m (spec: anti-líneas-rectas)
// - AndroidSettings interval: 3s
// - Buffer de 10 puntos → WriteBatch a Firestore
// - Foreground Service para background GPS
// ============================================================

enum EstadoTracking { inactivo, activo, finalizado }

class TrackingService with WidgetsBindingObserver {
  static final TrackingService instance = TrackingService._();
  TrackingService._() { WidgetsBinding.instance.addObserver(this); }

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

  // Cloud sync
  String? _firestoreSessionId;
  String? _firestoreUserId;
  final List<Map<String, dynamic>> _bufferPoints = []; // Buffer 10 puntos
  final _firestore = FirebaseFirestore.instance;

  final _estadoCtrl   = StreamController<EstadoTracking>.broadcast();
  final _coordCtrl    = StreamController<CoordenadasRutaModel>.broadcast();
  final _metricasCtrl = StreamController<MetricasTracking>.broadcast();
  final _sosCtrl      = StreamController<void>.broadcast();

  Stream<EstadoTracking>       get estadoStream    => _estadoCtrl.stream;
  Stream<CoordenadasRutaModel> get coordenadaStream => _coordCtrl.stream;
  Stream<MetricasTracking>     get metricasStream   => _metricasCtrl.stream;
  Stream<void>                 get sosStream        => _sosCtrl.stream;

  StreamSubscription<Position>? _gpsSub;
  Timer? _sosTimer, _notifTimer;

  bool get activo => _estado == EstadoTracking.activo;

  // ─── Lifecycle ──────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!activo) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _enBackground = true;
      _backgroundAt = DateTime.now();
      _sosTimer?.cancel();
    } else if (state == AppLifecycleState.resumed && _enBackground) {
      _enBackground = false;
      if (_backgroundAt != null && _ultimaVariacion != null) {
        _ultimaVariacion = _ultimaVariacion!.add(DateTime.now().difference(_backgroundAt!));
      }
      _backgroundAt = null;
      if (activo) _iniciarSOS();
    }
  }

  // ─── INICIAR ─────────────────────────────────────────────
  Future<bool> iniciarTracking({
    required int usuarioId,
    required int spotId,
    String? firestoreUserId,
  }) async {
    if (!await _checkPermisos()) return false;
    await _iniciarForegroundService();

    _usuarioId = usuarioId; _spotId = spotId;
    _firestoreUserId = firestoreUserId;
    _estado = EstadoTracking.activo;
    _inicio = DateTime.now();
    _secuencia = 0; _distanciaKm = 0.0; _velMax = 0.0;
    _ultimaVariacion = DateTime.now();
    _enBackground = false;
    _bufferPoints.clear();

    // SQLite local
    final ruta = RutaTrazadaModel(
        usuarioId: usuarioId, spotId: spotId, iniciadaEn: _inicio!);
    _rutaId = await SupDatabase.instance.insertarRuta(ruta);

    // Firestore session si hay usuario autenticado
    if (_firestoreUserId != null) {
      final sessionRef = _firestore
          .collection('users').doc(_firestoreUserId)
          .collection('sessions').doc();
      _firestoreSessionId = sessionRef.id;
      await sessionRef.set({
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'spotId': spotId,
      });
    }

    _estadoCtrl.add(_estado);
    _iniciarGPS();
    _iniciarSOS();
    _iniciarActualizacionNotif();
    return true;
  }

  // ─── FINALIZAR ───────────────────────────────────────────
  Future<RutaTrazadaModel?> finalizarTracking() async {
    if (_rutaId == null || !activo) return null;
    _gpsSub?.cancel(); _sosTimer?.cancel(); _notifTimer?.cancel();
    await FlutterForegroundTask.stopService();
    _estado = EstadoTracking.finalizado;

    // Flush buffer restante
    if (_bufferPoints.isNotEmpty && _firestoreUserId != null && _firestoreSessionId != null) {
      await _flushBuffer();
    }

    final dur = _inicio != null ? DateTime.now().difference(_inicio!).inMinutes : 0;
    final velMedia = dur > 0 ? _distanciaKm / (dur / 60) : 0.0;

    final ruta = RutaTrazadaModel(
      rutaId: _rutaId, usuarioId: _usuarioId, spotId: _spotId,
      iniciadaEn: _inicio!, finalizadaEn: DateTime.now(),
      distanciaKm: _distanciaKm, duracionMinutos: dur,
      velocidadMedia: velMedia, velocidadMaxima: _velMax,
    );
    await SupDatabase.instance.actualizarRuta(ruta);

    // Cerrar sesión en Firestore
    if (_firestoreUserId != null && _firestoreSessionId != null) {
      await _firestore
          .collection('users').doc(_firestoreUserId)
          .collection('sessions').doc(_firestoreSessionId)
          .update({'endTime': FieldValue.serverTimestamp(), 'status': 'completed'});
    }

    _estadoCtrl.add(_estado);
    return ruta;
  }

  void confirmarEstoyBien() {
    if (!activo) return;
    _ultimaVariacion = DateTime.now();
    _sosTimer?.cancel();
    _iniciarSOS();
  }

  // ─── GPS con specs anti-líneas-rectas ───────────────────
  void _iniciarGPS() {
    // Spec: distanceFilter 2m + interval 3s (AndroidSettings)
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,       // 2 metros obligatorios (spec)
      intervalDuration: const Duration(seconds: 3), // 3 segundos (spec)
    );
    _gpsSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_procesarPos);
  }

  void _procesarPos(Position pos) async {
    if (!activo || _rutaId == null) return;

    final velKmh = pos.speed * 3.6;
    if (velKmh > _velMax) _velMax = velKmh;

    if (_ultimaPos != null) {
      final dist = _haversine(_ultimaPos!.latitude, _ultimaPos!.longitude,
          pos.latitude, pos.longitude);
      if (dist > 0.002) {
        _distanciaKm += dist;
        _ultimaVariacion = DateTime.now();
      }
    }

    // SQLite local
    final coord = CoordenadasRutaModel(
      rutaId: _rutaId!, latitud: pos.latitude, longitud: pos.longitude,
      secuencia: _secuencia++, velocidadKmh: velKmh, timestamp: DateTime.now(),
    );
    await SupDatabase.instance.insertarCoordenada(coord);
    _coordCtrl.add(coord);

    // Buffer para Firestore (spec: flush cada 10 puntos)
    if (_firestoreUserId != null && _firestoreSessionId != null) {
      _bufferPoints.add({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': pos.speed,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
      if (_bufferPoints.length >= 10) await _flushBuffer();
    }

    final dur = _inicio != null ? DateTime.now().difference(_inicio!).inMinutes : 0;
    _metricasCtrl.add(MetricasTracking(
      distanciaKm: _distanciaKm, velocidadActualKmh: velKmh,
      velocidadMaximaKmh: _velMax, duracionMinutos: dur,
      latitud: pos.latitude, longitud: pos.longitude,
    ));
    _ultimaPos = pos;
  }

  // WriteBatch flush — spec: bajo consumo de red
  Future<void> _flushBuffer() async {
    if (_bufferPoints.isEmpty || _firestoreUserId == null || _firestoreSessionId == null) return;
    final toSend = List<Map<String, dynamic>>.from(_bufferPoints);
    _bufferPoints.clear();

    final batch = _firestore.batch();
    final pointsRef = _firestore
        .collection('users').doc(_firestoreUserId)
        .collection('sessions').doc(_firestoreSessionId)
        .collection('points');

    for (final p in toSend) {
      batch.set(pointsRef.doc(), p);
    }
    await batch.commit();
  }

  Future<void> _iniciarForegroundService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'supready_tracking',
        channelName: 'SUPReady — Remada activa',
        channelDescription: 'GPS activo durante la remada.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true, playSound: false),
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
      notificationText: 'GPS activo — 0.00 km',
      callback: _foregroundCallback,
    );
  }

  void _iniciarActualizacionNotif() {
    _notifTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!activo) return;
      FlutterForegroundTask.updateService(
        notificationTitle: '🏄 Remada en curso',
        notificationText: '${_distanciaKm.toStringAsFixed(2)} km · ${_durStr()}',
      );
    });
  }

  String _durStr() {
    if (_inicio == null) return '0m';
    final min = DateTime.now().difference(_inicio!).inMinutes;
    return min >= 60 ? '${min ~/ 60}h ${min % 60}m' : '${min}m';
  }

  void _iniciarSOS() {
    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_enBackground || _ultimaVariacion == null) return;
      if (DateTime.now().difference(_ultimaVariacion!).inMinutes >= 15) {
        _sosCtrl.add(null); _sosTimer?.cancel();
      }
    });
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1), dLon = _rad(lon2 - lon1);
    final a = sin(dLat/2)*sin(dLat/2) +
        cos(_rad(lat1))*cos(_rad(lat2))*sin(dLon/2)*sin(dLon/2);
    return R * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  double _rad(double d) => d * pi / 180;

  Future<bool> _checkPermisos() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p != LocationPermission.denied && p != LocationPermission.deniedForever;
  }
}

@pragma('vm:entry-point')
void _foregroundCallback() {
  FlutterForegroundTask.setTaskHandler(_TrackingTaskHandler());
}

class _TrackingTaskHandler extends TaskHandler {
  @override Future<void> onStart(DateTime t, TaskStarter s) async {}
  @override void onRepeatEvent(DateTime t) {}
  @override Future<void> onDestroy(DateTime t) async {}
}

class MetricasTracking {
  final double distanciaKm, velocidadActualKmh, velocidadMaximaKmh;
  final int duracionMinutos;
  final double latitud, longitud;
  const MetricasTracking({
    required this.distanciaKm, required this.velocidadActualKmh,
    required this.velocidadMaximaKmh, required this.duracionMinutos,
    required this.latitud, required this.longitud,
  });
  String get distanciaFormateada => '${distanciaKm.toStringAsFixed(2)} km';
  String get velocidadFormateada => '${velocidadActualKmh.toStringAsFixed(1)} km/h';
  String get duracionFormateada {
    final h = duracionMinutos ~/ 60, m = duracionMinutos % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
