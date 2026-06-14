import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/models.dart';
import 'sup_database.dart';

// ============================================================
// SUPReady v2.2 - Tracking robusto pantalla apagada
//
// FIXES:
//  - GPS guardado en SQLite en CADA punto (no en buffer)
//    → ruta se reconstruye completa aunque la app muera
//  - distanceFilter: 3m + interval: 5s
//    → balance entre precisión y batería
//  - Timer de backup cada 30s: guarda posición aunque
//    el usuario no se mueva (previene gaps en la ruta)
//  - WakeLock + ForegroundService: pantalla apagada OK
//  - Firebase sync: buffer 5 puntos (más frecuente)
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

  // Firebase
  String? _firestoreSessionId;
  String? _firestoreUserId;
  final List<Map<String, dynamic>> _bufferFirebase = [];
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
  Timer? _sosTimer, _notifTimer, _backupTimer;

  bool get activo => _estado == EstadoTracking.activo;

  // ─── Lifecycle ──────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!activo) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _enBackground = true;
      _backgroundAt = DateTime.now();
      _sosTimer?.cancel();
      // GPS sigue → WakeLock mantiene CPU activa con pantalla apagada
    } else if (state == AppLifecycleState.resumed && _enBackground) {
      _enBackground = false;
      if (_backgroundAt != null && _ultimaVariacion != null) {
        _ultimaVariacion = _ultimaVariacion!
            .add(DateTime.now().difference(_backgroundAt!));
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

    // 1. WakeLock: mantiene CPU activa con pantalla apagada
    await WakelockPlus.enable();

    // 2. Foreground Service: Android no puede matar el proceso
    await _iniciarForegroundService();

    _usuarioId = usuarioId;
    _spotId = spotId;
    _firestoreUserId = firestoreUserId;
    _estado = EstadoTracking.activo;
    _inicio = DateTime.now();
    _secuencia = 0;
    _distanciaKm = 0.0;
    _velMax = 0.0;
    _ultimaVariacion = DateTime.now();
    _enBackground = false;
    _bufferFirebase.clear();

    // SQLite: crear la sesión
    final ruta = RutaTrazadaModel(
        usuarioId: usuarioId, spotId: spotId, iniciadaEn: _inicio!);
    _rutaId = await SupDatabase.instance.insertarRuta(ruta);

    // Firebase: crear sesión en /users/{uid}/sessions/{id}
    if (_firestoreUserId != null) {
      try {
        final sessionRef = _firestore
            .collection('users').doc(_firestoreUserId)
            .collection('sessions').doc();
        _firestoreSessionId = sessionRef.id;
        await sessionRef.set({
          'startTime': FieldValue.serverTimestamp(),
          'status':    'active',
          'spotId':    spotId,
        });
      } catch (e) {
        // Firebase falla → sigue con SQLite local
        _firestoreSessionId = null;
      }
    }

    _estadoCtrl.add(_estado);
    _iniciarGPS();
    _iniciarSOS();
    _iniciarBackupTimer();
    _iniciarActualizacionNotif();
    return true;
  }

  // ─── FINALIZAR ───────────────────────────────────────────
  Future<RutaTrazadaModel?> finalizarTracking() async {
    if (_rutaId == null || !activo) return null;

    _gpsSub?.cancel();
    _sosTimer?.cancel();
    _notifTimer?.cancel();
    _backupTimer?.cancel();

    await WakelockPlus.disable();
    await FlutterForegroundTask.stopService();

    _estado = EstadoTracking.finalizado;

    // Flush Firebase buffer restante
    if (_bufferFirebase.isNotEmpty) {
      try { await _flushFirebase(); } catch (_) {}
    }

    final dur = _inicio != null
        ? DateTime.now().difference(_inicio!).inMinutes : 0;
    final velMedia = dur > 0 ? _distanciaKm / (dur / 60) : 0.0;

    final ruta = RutaTrazadaModel(
      rutaId:          _rutaId,
      usuarioId:       _usuarioId,
      spotId:          _spotId,
      iniciadaEn:      _inicio!,
      finalizadaEn:    DateTime.now(),
      distanciaKm:     _distanciaKm,
      duracionMinutos: dur,
      velocidadMedia:  velMedia,
      velocidadMaxima: _velMax,
    );

    // Actualizar SQLite con stats finales
    await SupDatabase.instance.actualizarRuta(ruta);

    // Cerrar sesión en Firebase
    if (_firestoreUserId != null && _firestoreSessionId != null) {
      try {
        await _firestore
            .collection('users').doc(_firestoreUserId)
            .collection('sessions').doc(_firestoreSessionId)
            .update({
          'endTime':       FieldValue.serverTimestamp(),
          'status':        'completed',
          'distanciaKm':   _distanciaKm,
          'duracionMin':   dur,
          'velocidadMedia': velMedia,
        });
      } catch (_) {}
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

  // ─── GPS con config óptima para ruta precisa ─────────────
  void _iniciarGPS() {
    // distanceFilter: 3m → puntos suficientes para ver la ruta bien
    // intervalDuration: 5s → balance batería/precisión
    final settings = AndroidSettings(
      accuracy:         LocationAccuracy.high,
      distanceFilter:   3,                          // cada 3 metros
      intervalDuration: const Duration(seconds: 5), // máx cada 5s
    );
    _gpsSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_procesarPos);
  }

  void _procesarPos(Position pos) async {
    if (!activo || _rutaId == null) return;

    final velKmh = pos.speed.clamp(0.0, 50.0) * 3.6; // filtrar valores inválidos
    if (velKmh > _velMax) _velMax = velKmh;

    // Calcular distancia incremental
    if (_ultimaPos != null) {
      final dist = _haversine(
          _ultimaPos!.latitude, _ultimaPos!.longitude,
          pos.latitude, pos.longitude);
      if (dist > 0.001) { // filtrar < 1m (jitter GPS)
        _distanciaKm += dist;
        _ultimaVariacion = DateTime.now();
      }
    }

    // ✅ GUARDAR EN SQLITE INMEDIATAMENTE (cada punto)
    // Esto garantiza que la ruta se preserva aunque la app muera
    final coord = CoordenadasRutaModel(
      rutaId:       _rutaId!,
      latitud:      pos.latitude,
      longitud:     pos.longitude,
      secuencia:    _secuencia++,
      velocidadKmh: velKmh,
      timestamp:    DateTime.now(),
    );
    await SupDatabase.instance.insertarCoordenada(coord);
    _coordCtrl.add(coord);

    // ✅ BUFFER FIREBASE (flush cada 5 puntos = ~15-25s)
    if (_firestoreUserId != null && _firestoreSessionId != null) {
      _bufferFirebase.add({
        'latitude':  pos.latitude,
        'longitude': pos.longitude,
        'speed':     pos.speed,
        'velKmh':    velKmh,
        'sequence':  coord.secuencia,
        'timestamp': Timestamp.fromDate(coord.timestamp),
      });
      if (_bufferFirebase.length >= 5) {
        _flushFirebase(); // no await para no bloquear el GPS
      }
    }

    // Actualizar métricas en SQLite periódicamente (cada 10 puntos)
    if (_secuencia % 10 == 0) {
      final dur = _inicio != null
          ? DateTime.now().difference(_inicio!).inMinutes : 0;
      final velMedia = dur > 0 ? _distanciaKm / (dur / 60) : 0.0;
      final rutaActualizada = RutaTrazadaModel(
        rutaId:          _rutaId,
        usuarioId:       _usuarioId,
        spotId:          _spotId,
        iniciadaEn:      _inicio!,
        distanciaKm:     _distanciaKm,
        duracionMinutos: dur,
        velocidadMedia:  velMedia,
        velocidadMaxima: _velMax,
      );
      await SupDatabase.instance.actualizarRuta(rutaActualizada);
    }

    final duracion = _inicio != null
        ? DateTime.now().difference(_inicio!).inMinutes : 0;
    _metricasCtrl.add(MetricasTracking(
      distanciaKm:         _distanciaKm,
      velocidadActualKmh:  velKmh,
      velocidadMaximaKmh:  _velMax,
      duracionMinutos:     duracion,
      latitud:             pos.latitude,
      longitud:            pos.longitude,
    ));
    _ultimaPos = pos;
  }

  // Timer de backup: guarda posición cada 30s aunque no haya movimiento
  // Evita gaps en la ruta si el GPS no registra movimiento
  void _iniciarBackupTimer() {
    _backupTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!activo || _rutaId == null || _ultimaPos == null) return;
      // Guardar un punto de "heartbeat" para mantener continuidad
      final coord = CoordenadasRutaModel(
        rutaId:       _rutaId!,
        latitud:      _ultimaPos!.latitude,
        longitud:     _ultimaPos!.longitude,
        secuencia:    _secuencia++,
        velocidadKmh: 0,
        timestamp:    DateTime.now(),
      );
      await SupDatabase.instance.insertarCoordenada(coord);
    });
  }

  Future<void> _flushFirebase() async {
    if (_bufferFirebase.isEmpty ||
        _firestoreUserId == null ||
        _firestoreSessionId == null) return;

    final toSend = List<Map<String, dynamic>>.from(_bufferFirebase);
    _bufferFirebase.clear();

    try {
      final batch = _firestore.batch();
      final ref = _firestore
          .collection('users').doc(_firestoreUserId)
          .collection('sessions').doc(_firestoreSessionId)
          .collection('points');
      for (final p in toSend) {
        batch.set(ref.doc(), p);
      }
      await batch.commit();
    } catch (_) {
      // Si falla Firebase, los puntos ya están en SQLite → OK
    }
  }

  Future<void> _iniciarForegroundService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId:          'supready_tracking',
        channelName:        'SUPReady — Remada activa',
        channelDescription: 'GPS activo. Podés apagar la pantalla.',
        channelImportance:  NotificationChannelImportance.LOW,
        priority:           NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:                ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot:              false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock:              true,
        allowWifiLock:              true,
      ),
    );
    await FlutterForegroundTask.startService(
      serviceId:         1001,
      notificationTitle: '🏄 Remada en curso',
      notificationText:  'GPS activo — podés apagar la pantalla',
      callback:          _foregroundCallback,
    );
  }

  void _iniciarActualizacionNotif() {
    _notifTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!activo) return;
      final dur = _inicio != null
          ? DateTime.now().difference(_inicio!).inMinutes : 0;
      final h = dur ~/ 60; final m = dur % 60;
      final durStr = h > 0 ? '${h}h ${m}m' : '${m}m';
      final velStr = _ultimaPos != null
          ? '${(_ultimaPos!.speed * 3.6).toStringAsFixed(1)} km/h' : '--';
      FlutterForegroundTask.updateService(
        notificationTitle: '🏄 Remando — ${_distanciaKm.toStringAsFixed(2)} km',
        notificationText:  '$durStr · $velStr · ${_secuencia} pts GPS guardados',
      );
    });
  }

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

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat/2)*sin(dLat/2) +
        cos(_rad(lat1))*cos(_rad(lat2))*sin(dLon/2)*sin(dLon/2);
    return R * 2 * atan2(sqrt(a), sqrt(1-a));
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
    required this.distanciaKm,
    required this.velocidadActualKmh,
    required this.velocidadMaximaKmh,
    required this.duracionMinutos,
    required this.latitud,
    required this.longitud,
  });

  String get distanciaFormateada => '${distanciaKm.toStringAsFixed(2)} km';
  String get velocidadFormateada => '${velocidadActualKmh.toStringAsFixed(1)} km/h';
  String get duracionFormateada {
    final h = duracionMinutos ~/ 60;
    final m = duracionMinutos % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
