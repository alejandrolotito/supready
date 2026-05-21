import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../../data/models/models.dart';
import '../../data/datasources/local/sup_database.dart';

// ============================================================
// SUPReady - Servicio de Trackeo GPS
// ERS RF3.1: Captura cada 5s en background
// ERS RF3.4: SOS automático si no hay variación en 15 min
// ============================================================

enum EstadoTracking { inactivo, activo, pausado, finalizado }

class TrackingService {
  static final TrackingService instance = TrackingService._();
  TrackingService._();

  // State
  EstadoTracking _estado = EstadoTracking.inactivo;
  int? _rutaId;
  int _secuenciaActual = 0;
  double _distanciaAcumuladaKm = 0.0;
  double _velocidadMaxima = 0.0;
  DateTime? _inicioRuta;
  Position? _ultimaPosicion;
  DateTime? _ultimaVariacion;

  // Stream controllers
  final _estadoController = StreamController<EstadoTracking>.broadcast();
  final _coordenadaController = StreamController<CoordenadasRutaModel>.broadcast();
  final _metricasController = StreamController<MetricasTracking>.broadcast();
  final _sosController = StreamController<void>.broadcast();

  Stream<EstadoTracking> get estadoStream => _estadoController.stream;
  Stream<CoordenadasRutaModel> get coordenadaStream => _coordenadaController.stream;
  Stream<MetricasTracking> get metricasStream => _metricasController.stream;
  Stream<void> get sosStream => _sosController.stream;

  StreamSubscription<Position>? _locationSubscription;
  Timer? _sosTimer;

  EstadoTracking get estado => _estado;
  double get distanciaKm => _distanciaAcumuladaKm;
  int get duracionMinutos => _inicioRuta != null
      ? DateTime.now().difference(_inicioRuta!).inMinutes
      : 0;

  // --- INICIAR REMADA (ERS CU02) ---
  Future<bool> iniciarTracking({
    required int usuarioId,
    required int spotId,
  }) async {
    final permiso = await _verificarPermisos();
    if (!permiso) return false;

    _estado = EstadoTracking.activo;
    _inicioRuta = DateTime.now();
    _secuenciaActual = 0;
    _distanciaAcumuladaKm = 0.0;
    _velocidadMaxima = 0.0;
    _ultimaVariacion = DateTime.now();

    // Crear registro de ruta en SQLite
    final ruta = RutaTrazadaModel(
      usuarioId: usuarioId,
      spotId: spotId,
      iniciadaEn: _inicioRuta!,
    );
    _rutaId = await SupDatabase.instance.insertarRuta(ruta);

    _estadoController.add(_estado);
    _iniciarEscuchaGPS();
    _iniciarTimerSOS();

    return true;
  }

  // --- FINALIZAR (Long Press 3s según ERS §6 Water Shield UX) ---
  Future<RutaTrazadaModel?> finalizarTracking() async {
    if (_rutaId == null || _estado != EstadoTracking.activo) return null;

    _locationSubscription?.cancel();
    _sosTimer?.cancel();
    _estado = EstadoTracking.finalizado;

    final rutaFinalizada = RutaTrazadaModel(
      rutaId: _rutaId,
      usuarioId: 0,
      spotId: 0,
      iniciadaEn: _inicioRuta!,
      finalizadaEn: DateTime.now(),
      distanciaKm: _distanciaAcumuladaKm,
      duracionMinutos: duracionMinutos,
      velocidadMedia: duracionMinutos > 0
          ? _distanciaAcumuladaKm / (duracionMinutos / 60)
          : 0.0,
      velocidadMaxima: _velocidadMaxima,
    );

    await SupDatabase.instance.actualizarRuta(rutaFinalizada);
    _estadoController.add(_estado);
    return rutaFinalizada;
  }

  // --- GPS Background (ERS RF3.1) ---
  void _iniciarEscuchaGPS() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // metros mínimos entre capturas
      ),
    ).listen(_procesarPosicion);
  }

  void _procesarPosicion(Position position) async {
    if (_estado != EstadoTracking.activo || _rutaId == null) return;

    // Calcular distancia desde última posición
    if (_ultimaPosicion != null) {
      final dist = _calcularDistanciaKm(
        _ultimaPosicion!.latitude, _ultimaPosicion!.longitude,
        position.latitude, position.longitude,
      );
      // Filtrar jitter GPS (< 2m)
      if (dist > 0.002) {
        _distanciaAcumuladaKm += dist;
        _ultimaVariacion = DateTime.now();
      }
    }

    // Velocidad máxima
    final velActual = (position.speed * 3.6); // m/s -> km/h
    if (velActual > _velocidadMaxima) _velocidadMaxima = velActual;

    // Guardar coordenada en SQLite (offline first)
    final coord = CoordenadasRutaModel(
      rutaId: _rutaId!,
      latitud: position.latitude,
      longitud: position.longitude,
      secuencia: _secuenciaActual++,
      timestamp: DateTime.now(),
    );
    await SupDatabase.instance.insertarCoordenada(coord);
    _coordenadaController.add(coord);

    // Emitir métricas para UI
    _metricasController.add(MetricasTracking(
      distanciaKm: _distanciaAcumuladaKm,
      velocidadActualKmh: velActual,
      velocidadMaximaKmh: _velocidadMaxima,
      duracionMinutos: duracionMinutos,
      latitud: position.latitude,
      longitud: position.longitude,
    ));

    _ultimaPosicion = position;
  }

  // --- Timer SOS (ERS RF3.4): alerta si sin variación 15 min ---
  void _iniciarTimerSOS() {
    _sosTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_ultimaVariacion == null) return;
      final sinMovimiento = DateTime.now().difference(_ultimaVariacion!).inMinutes;
      if (sinMovimiento >= 15) {
        _sosController.add(null);
        timer.cancel();
      }
    });
  }

  // --- Haversine (distancia GPS) ---
  double _calcularDistanciaKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _rad(double deg) => deg * pi / 180;

  Future<bool> _verificarPermisos() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  void dispose() {
    _locationSubscription?.cancel();
    _sosTimer?.cancel();
    _estadoController.close();
    _coordenadaController.close();
    _metricasController.close();
    _sosController.close();
  }
}

// ----------------------------------------------------------
// DTO de métricas para la pantalla de tracking
// ----------------------------------------------------------
class MetricasTracking {
  final double distanciaKm;
  final double velocidadActualKmh;
  final double velocidadMaximaKmh;
  final int duracionMinutos;
  final double latitud;
  final double longitud;

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
