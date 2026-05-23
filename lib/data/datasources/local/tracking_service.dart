import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../../models/models.dart';
import 'sup_database.dart';

// ============================================================
// SUPReady v3 - Servicio de Trackeo GPS
// - Velocidad real por coordenada (para tramos coloreados)
// - GPS cada 5s, offline first
// - SOS automático 15 min sin movimiento
// ============================================================

enum EstadoTracking { inactivo, activo, pausado, finalizado }

class TrackingService {
  static final TrackingService instance = TrackingService._();
  TrackingService._();

  EstadoTracking _estado = EstadoTracking.inactivo;
  int? _rutaId;
  int _usuarioId = 0, _spotId = 0;
  int _secuencia = 0;
  double _distanciaKm = 0.0, _velMax = 0.0;
  DateTime? _inicio;
  Position? _ultimaPos;
  DateTime? _ultimaVariacion;

  final _estadoCtrl    = StreamController<EstadoTracking>.broadcast();
  final _coordCtrl     = StreamController<CoordenadasRutaModel>.broadcast();
  final _metricasCtrl  = StreamController<MetricasTracking>.broadcast();
  final _sosCtrl       = StreamController<void>.broadcast();

  Stream<EstadoTracking>        get estadoStream   => _estadoCtrl.stream;
  Stream<CoordenadasRutaModel>  get coordenadaStream => _coordCtrl.stream;
  Stream<MetricasTracking>      get metricasStream  => _metricasCtrl.stream;
  Stream<void>                  get sosStream       => _sosCtrl.stream;

  StreamSubscription<Position>? _gpsSub;
  Timer? _sosTimer;

  EstadoTracking get estado => _estado;

  Future<bool> iniciarTracking({required int usuarioId, required int spotId}) async {
    if (!await _checkPermisos()) return false;
    _usuarioId = usuarioId; _spotId = spotId;
    _estado = EstadoTracking.activo;
    _inicio = DateTime.now();
    _secuencia = 0; _distanciaKm = 0.0; _velMax = 0.0;
    _ultimaVariacion = DateTime.now();

    final ruta = RutaTrazadaModel(usuarioId: usuarioId, spotId: spotId, iniciadaEn: _inicio!);
    _rutaId = await SupDatabase.instance.insertarRuta(ruta);

    _estadoCtrl.add(_estado);
    _iniciarGPS();
    _iniciarSOS();
    return true;
  }

  Future<RutaTrazadaModel?> finalizarTracking() async {
    if (_rutaId == null || _estado != EstadoTracking.activo) return null;
    _gpsSub?.cancel(); _sosTimer?.cancel();
    _estado = EstadoTracking.finalizado;

    final duracion = _inicio != null ? DateTime.now().difference(_inicio!).inMinutes : 0;
    final velMedia = duracion > 0 ? _distanciaKm / (duracion / 60) : 0.0;

    final ruta = RutaTrazadaModel(
      rutaId: _rutaId, usuarioId: _usuarioId, spotId: _spotId,
      iniciadaEn: _inicio!, finalizadaEn: DateTime.now(),
      distanciaKm: _distanciaKm, duracionMinutos: duracion,
      velocidadMedia: velMedia, velocidadMaxima: _velMax,
    );
    await SupDatabase.instance.actualizarRuta(ruta);
    _estadoCtrl.add(_estado);
    return ruta;
  }

  void _iniciarGPS() {
    _gpsSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best, distanceFilter: 5,
    )).listen(_procesarPos);
  }

  void _procesarPos(Position pos) async {
    if (_estado != EstadoTracking.activo || _rutaId == null) return;

    // Velocidad real del GPS (m/s → km/h)
    final velKmh = pos.speed * 3.6;
    if (velKmh > _velMax) _velMax = velKmh;

    if (_ultimaPos != null) {
      final dist = _haversine(_ultimaPos!.latitude, _ultimaPos!.longitude, pos.latitude, pos.longitudee);
      if (dist > 0.002) { // filtrar jitter < 2m
        _distanciaKm += dist;
        _ultimaVariacion = DateTime.now();
      }
    }

    final coord = CoordenadasRutaModel(
      rutaId: _rutaId!, latitud: pos.latitude, longitud: pos.longitudee,
      secuencia: _secuencia++, velocidadKmh: velKmh, timestamp: DateTime.now(),
    );
    await SupDatabase.instance.insertarCoordenada(coord);
    _coordCtrl.add(coord);

    final duracion = _inicio != null ? DateTime.now().difference(_inicio!).inMinutes : 0;
    _metricasCtrl.add(MetricasTracking(
      distanciaKm: _distanciaKm, velocidadActualKmh: velKmh,
      velocidadMaximaKmh: _velMax, duracionMinutos: duracion,
      latitud: pos.latitude, longitud: pos.longitude,
    ));
    _ultimaPos = pos;
  }

  void _iniciarSOS() {
    _sosTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_ultimaVariacion == null) return;
      if (DateTime.now().difference(_ultimaVariacion!).inMinutes >= 15) {
        _sosCtrl.add(null);
        _sosTimer?.cancel();
      }
    });
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1), dLon = _rad(lon2 - lon1);
    final a = sin(dLat/2)*sin(dLat/2) + cos(_rad(lat1))*cos(_rad(lat2))*sin(dLon/2)*sin(dLon/2);
    return R * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  double _rad(double d) => d * pi / 180;

  Future<bool> _checkPermisos() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p != LocationPermission.denied && p != LocationPermission.deniedForever;
  }

  void dispose() {
    _gpsSub?.cancel(); _sosTimer?.cancel();
    _estadoCtrl.close(); _coordCtrl.close(); _metricasCtrl.close(); _sosCtrl.close();
  }
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
