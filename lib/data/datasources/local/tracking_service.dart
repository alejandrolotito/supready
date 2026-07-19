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
// SUPReady v2.4 - Tracking preciso con cálculo GPS real
//
// MEJORAS:
//  - Velocidad calculada entre puntos consecutivos (no pos.speed)
//    → más preciso que el doppler del GPS Android
//  - Suavizado exponencial (EMA) para evitar picos falsos
//  - Segmentación de tramos por velocidad
//    (lento <5 km/h / medio 5-12 / rápido >12)
//  - Filtro de puntos duplicados (jitter GPS < 1m)
//  - Filtro de velocidades imposibles (> 30 km/h para SUP)
//  - Haversine para distancia exacta en metros
// ============================================================

enum EstadoTracking { inactivo, activo, finalizado }

/// Tramo de velocidad para colorear la ruta
enum TramoVelocidad { lento, medio, rapido }

class PuntoGPS {
  final double latitud, longitud, velocidadKmh;
  final DateTime timestamp;
  final TramoVelocidad tramo;
  final int secuencia;

  const PuntoGPS({
    required this.latitud,
    required this.longitud,
    required this.velocidadKmh,
    required this.timestamp,
    required this.tramo,
    required this.secuencia,
  });

  TramoVelocidad get tramoVelocidad {
    if (velocidadKmh < 5) return TramoVelocidad.lento;
    if (velocidadKmh < 12) return TramoVelocidad.medio;
    return TramoVelocidad.rapido;
  }
}

class TrackingService with WidgetsBindingObserver {
  static final TrackingService instance = TrackingService._();
  TrackingService._() { WidgetsBinding.instance.addObserver(this); }

  EstadoTracking _estado = EstadoTracking.inactivo;
  int? _rutaId;
  int _usuarioId = 0, _spotId = 0;
  int _secuencia = 0;
  double _distanciaKm = 0.0, _velMax = 0.0;
  double _velSuavizada = 0.0;           // EMA de velocidad
  DateTime? _inicio;
  Position? _ultimaPos;
  DateTime? _ultimaTs;                   // timestamp del último punto válido
  DateTime? _ultimaVariacion;
  DateTime? _backgroundAt;
  bool _enBackground = false;

  // Ventana de últimos N puntos para suavizado
  final List<double> _ventanaVel = [];
  static const int _ventanaSize = 5;

  // Buffer de tramos para la UI
  final List<PuntoGPS> _puntosGPS = [];

  // Firebase
  String? _firestoreSessionId;
  String? _firestoreUserId;
  final List<Map<String, dynamic>> _bufferFirebase = [];
  final _firestore = FirebaseFirestore.instance;

  final _estadoCtrl   = StreamController<EstadoTracking>.broadcast();
  final _coordCtrl    = StreamController<CoordenadasRutaModel>.broadcast();
  final _metricasCtrl = StreamController<MetricasTracking>.broadcast();
  final _sosCtrl      = StreamController<void>.broadcast();

  Stream<EstadoTracking>  get estadoStream    => _estadoCtrl.stream;
  Stream<CoordenadasRutaModel> get coordenadaStream => _coordCtrl.stream;
  Stream<MetricasTracking> get metricasStream  => _metricasCtrl.stream;
  Stream<void>             get sosStream       => _sosCtrl.stream;

  List<PuntoGPS> get puntosGPS => List.unmodifiable(_puntosGPS);

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

    await WakelockPlus.enable();
    await _iniciarForegroundService();

    _usuarioId = usuarioId;
    _spotId = spotId;
    _firestoreUserId = firestoreUserId;
    _estado = EstadoTracking.activo;
    _inicio = DateTime.now();
    _secuencia = 0;
    _distanciaKm = 0.0;
    _velMax = 0.0;
    _velSuavizada = 0.0;
    _ultimaVariacion = DateTime.now();
    _enBackground = false;
    _bufferFirebase.clear();
    _puntosGPS.clear();
    _ventanaVel.clear();
    _ultimaPos = null;
    _ultimaTs = null;

    final ruta = RutaTrazadaModel(
        usuarioId: usuarioId, spotId: spotId, iniciadaEn: _inicio!);
    _rutaId = await SupDatabase.instance.insertarRuta(ruta);

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
      } catch (_) { _firestoreSessionId = null; }
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
    await SupDatabase.instance.actualizarRuta(ruta);

    if (_firestoreUserId != null && _firestoreSessionId != null) {
      try {
        await _firestore
            .collection('users').doc(_firestoreUserId)
            .collection('sessions').doc(_firestoreSessionId)
            .update({
          'endTime':        FieldValue.serverTimestamp(),
          'status':         'completed',
          'distanciaKm':    _distanciaKm,
          'duracionMin':    dur,
          'velocidadMedia': velMedia,
          'velocidadMaxima':_velMax,
          'totalPuntos':    _secuencia,
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

  // ─── GPS ─────────────────────────────────────────────────
  void _iniciarGPS() {
    final settings = AndroidSettings(
      accuracy:         LocationAccuracy.high,
      distanceFilter:   2,                          // 2m mínimo entre puntos
      intervalDuration: const Duration(seconds: 3), // cada 3s máximo
    );
    _gpsSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_procesarPos);
  }

  void _procesarPos(Position pos) async {
    if (!activo || _rutaId == null) return;

    final ahora = DateTime.now();

    // ── 1. CALCULAR VELOCIDAD REAL ENTRE PUNTOS ───────────
    double velKmh = 0.0;

    if (_ultimaPos != null && _ultimaTs != null) {
      final distM = _haversineMetros(
          _ultimaPos!.latitude, _ultimaPos!.longitude,
          pos.latitude, pos.longitude);
      final dtSeg = ahora.difference(_ultimaTs!).inMilliseconds / 1000.0;

      // Filtro: ignorar puntos < 1m (jitter GPS) o dt < 1s
      if (distM < 1.0 || dtSeg < 0.5) return;

      // Velocidad instantánea = distancia / tiempo
      final velInstKmh = (distM / dtSeg) * 3.6;

      // Filtro: velocidad imposible para SUP (> 35 km/h)
      if (velInstKmh > 35.0) return;

      // ── 2. SUAVIZADO EMA (ventana de 5 puntos) ──────────
      _ventanaVel.add(velInstKmh);
      if (_ventanaVel.length > _ventanaSize) _ventanaVel.removeAt(0);

      // Media móvil simple sobre la ventana
      velKmh = _ventanaVel.reduce((a, b) => a + b) / _ventanaVel.length;

      // EMA adicional (α=0.4) para suavizar más
      _velSuavizada = _velSuavizada == 0
          ? velKmh
          : 0.4 * velKmh + 0.6 * _velSuavizada;
      velKmh = _velSuavizada;

      // Actualizar máxima real
      if (velInstKmh > _velMax) _velMax = velInstKmh;

      // ── 3. ACUMULAR DISTANCIA ────────────────────────────
      _distanciaKm += distM / 1000.0;
      _ultimaVariacion = ahora;
    }

    _ultimaTs = ahora;

    // ── 4. DETERMINAR TRAMO DE VELOCIDAD ─────────────────
    final tramo = velKmh < 5.0
        ? TramoVelocidad.lento
        : velKmh < 12.0
            ? TramoVelocidad.medio
            : TramoVelocidad.rapido;

    // ── 5. GUARDAR EN SQLITE INMEDIATAMENTE ───────────────
    final coord = CoordenadasRutaModel(
      rutaId:       _rutaId!,
      latitud:      pos.latitude,
      longitud:     pos.longitude,
      secuencia:    _secuencia,
      velocidadKmh: velKmh,
      timestamp:    ahora,
    );
    await SupDatabase.instance.insertarCoordenada(coord);

    // Agregar a lista de puntos en memoria (para la UI)
    _puntosGPS.add(PuntoGPS(
      latitud:      pos.latitude,
      longitud:     pos.longitude,
      velocidadKmh: velKmh,
      timestamp:    ahora,
      tramo:        tramo,
      secuencia:    _secuencia,
    ));
    _secuencia++;

    _coordCtrl.add(coord);

    // ── 6. BUFFER FIREBASE (flush cada 5 puntos) ──────────
    if (_firestoreUserId != null && _firestoreSessionId != null) {
      _bufferFirebase.add({
        'latitude':  pos.latitude,
        'longitude': pos.longitude,
        'velKmh':    velKmh,
        'tramo':     tramo.name,
        'sequence':  coord.secuencia,
        'timestamp': Timestamp.fromDate(ahora),
      });
      if (_bufferFirebase.length >= 5) {
        _flushFirebase(); // no await → no bloquea GPS
      }
    }

    // ── 7. ACTUALIZAR STATS en SQLite cada 10 puntos ──────
    if (_secuencia % 10 == 0) {
      final dur = _inicio != null
          ? DateTime.now().difference(_inicio!).inMinutes : 0;
      await SupDatabase.instance.actualizarRuta(RutaTrazadaModel(
        rutaId:          _rutaId,
        usuarioId:       _usuarioId,
        spotId:          _spotId,
        iniciadaEn:      _inicio!,
        distanciaKm:     _distanciaKm,
        duracionMinutos: dur,
        velocidadMedia:  dur > 0 ? _distanciaKm / (dur / 60) : 0,
        velocidadMaxima: _velMax,
      ));
    }

    // ── 8. EMITIR MÉTRICAS a la UI ────────────────────────
    final duracion = _inicio != null
        ? DateTime.now().difference(_inicio!).inMinutes : 0;
    _metricasCtrl.add(MetricasTracking(
      distanciaKm:        _distanciaKm,
      velocidadActualKmh: velKmh,
      velocidadMaximaKmh: _velMax,
      duracionMinutos:    duracion,
      latitud:            pos.latitude,
      longitud:           pos.longitude,
      tramo:              tramo,
      puntosGPS:          List.unmodifiable(_puntosGPS),
    ));

    _ultimaPos = pos;
  }

  // Timer backup: heartbeat cada 30s si hay posición conocida
  void _iniciarBackupTimer() {
    _backupTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!activo || _rutaId == null || _ultimaPos == null) return;
      final ahora = DateTime.now();
      final coord = CoordenadasRutaModel(
        rutaId:       _rutaId!,
        latitud:      _ultimaPos!.latitude,
        longitud:     _ultimaPos!.longitude,
        secuencia:    _secuencia++,
        velocidadKmh: 0,
        timestamp:    ahora,
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
      for (final p in toSend) { batch.set(ref.doc(), p); }
      await batch.commit();
    } catch (_) {}
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
      FlutterForegroundTask.updateService(
        notificationTitle: '🏄 ${_distanciaKm.toStringAsFixed(2)} km · $durStr',
        notificationText:
            '${_velSuavizada.toStringAsFixed(1)} km/h · '
            'Máx ${_velMax.toStringAsFixed(1)} · '
            '${_secuencia} pts GPS',
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

  // ─── Haversine en metros ──────────────────────────────────
  double _haversineMetros(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Radio en metros
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

// ─── DTO de métricas ─────────────────────────────────────────
class MetricasTracking {
  final double distanciaKm, velocidadActualKmh, velocidadMaximaKmh;
  final int duracionMinutos;
  final double latitud, longitud;
  final TramoVelocidad tramo;
  final List<PuntoGPS> puntosGPS;

  const MetricasTracking({
    required this.distanciaKm,
    required this.velocidadActualKmh,
    required this.velocidadMaximaKmh,
    required this.duracionMinutos,
    required this.latitud,
    required this.longitud,
    required this.tramo,
    required this.puntosGPS,
  });

  String get distanciaFormateada => '${distanciaKm.toStringAsFixed(2)} km';
  String get velocidadFormateada => '${velocidadActualKmh.toStringAsFixed(1)} km/h';
  String get duracionFormateada {
    final h = duracionMinutos ~/ 60;
    final m = duracionMinutos % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
