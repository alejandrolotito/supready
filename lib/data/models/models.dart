// ============================================================
// SUPReady - Modelos de Datos
// Según Diccionario de Arquitectura ERS §5
// ============================================================

/// Niveles de experiencia del palista
enum NivelExperiencia { principiante, intermedio, avanzado }

/// Estado del Semáforo SUP Ready Index (ERS RF2.1)
enum SupReadyIndex { verde, amarillo, rojo, sinDatos }

// ----------------------------------------------------------
// ENTIDAD: Usuario (Tabla USUARIOS)
// ----------------------------------------------------------
class UsuarioModel {
  final int? usuarioId;
  final String nombre;
  final String apellido;
  final String email;
  final String? googleId;
  final String? avatarUrl;
  final NivelExperiencia nivelExperiencia;

  const UsuarioModel({
    this.usuarioId,
    required this.nombre,
    required this.apellido,
    required this.email,
    this.googleId,
    this.avatarUrl,
    this.nivelExperiencia = NivelExperiencia.principiante,
  });

  String get nombreCompleto => '$nombre $apellido';

  Map<String, dynamic> toMap() => {
    'usuario_id': usuarioId,
    'nombre': nombre,
    'apellido': apellido,
    'email': email,
    'google_id': googleId,
    'avatar_url': avatarUrl,
    'nivel_experiencia': nivelExperiencia.name,
  };

  factory UsuarioModel.fromMap(Map<String, dynamic> map) => UsuarioModel(
    usuarioId: map['usuario_id'] as int?,
    nombre: map['nombre'] as String,
    apellido: map['apellido'] as String,
    email: map['email'] as String,
    googleId: map['google_id'] as String?,
    avatarUrl: map['avatar_url'] as String?,
    nivelExperiencia: NivelExperiencia.values.firstWhere(
      (e) => e.name == map['nivel_experiencia'],
      orElse: () => NivelExperiencia.principiante,
    ),
  );
}

// ----------------------------------------------------------
// ENTIDAD: Spot (Punto de navegación)
// ----------------------------------------------------------
class SpotModel {
  final int? spotId;
  final String nombre;
  final double latitud;
  final double longitud;
  final String descripcion;
  final CondicionesClimaticasModel? condiciones;

  const SpotModel({
    this.spotId,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    this.descripcion = '',
    this.condiciones,
  });

  SupReadyIndex get indiceViabilidad {
    final c = condiciones;
    if (c == null) return SupReadyIndex.sinDatos;
    // Algoritmo SUP Ready Index (ERS RF2.1)
    if (c.vientoKts > 15 || c.rafagasKts > 18 || c.olasMetros > 1.0 || c.esOffshore) {
      return SupReadyIndex.rojo;
    }
    if (c.vientoKts >= 9 || c.esCrossShore || c.olasMetros >= 0.5) {
      return SupReadyIndex.amarillo;
    }
    return SupReadyIndex.verde;
  }
}

// ----------------------------------------------------------
// ENTIDAD: Condiciones Climáticas (API Clima Marítimo)
// ----------------------------------------------------------
class CondicionesClimaticasModel {
  final double vientoKts;
  final double rafagasKts;
  final double olasMetros;
  final double dirVientoGrados;
  final bool esOffshore;
  final bool esCrossShore;
  final DateTime actualizadoEn;

  const CondicionesClimaticasModel({
    required this.vientoKts,
    required this.rafagasKts,
    required this.olasMetros,
    required this.dirVientoGrados,
    required this.esOffshore,
    required this.esCrossShore,
    required this.actualizadoEn,
  });

  factory CondicionesClimaticasModel.fromApiJson(Map<String, dynamic> json) {
    final windSpeedMs = (json['wind']?['speed'] ?? 0.0) as num;
    final windGustMs  = (json['wind']?['gust']  ?? 0.0) as num;
    final wavesM      = (json['waves']?['height'] ?? 0.0) as num;
    final windDeg     = (json['wind']?['direction'] ?? 0.0) as num;

    // 1 m/s = 1.94384 kts
    final viento  = windSpeedMs.toDouble() * 1.94384;
    final rafagas = windGustMs.toDouble() * 1.94384;

    return CondicionesClimaticasModel(
      vientoKts: viento,
      rafagasKts: rafagas,
      olasMetros: wavesM.toDouble(),
      dirVientoGrados: windDeg.toDouble(),
      esOffshore: _calcularOffshore(windDeg.toDouble()),
      esCrossShore: _calcularCrossShore(windDeg.toDouble()),
      actualizadoEn: DateTime.now(),
    );
  }

  // Simplificado: offshore si viene del interior (depende del spot, lógica completa en backend)
  static bool _calcularOffshore(double grados) => grados >= 315 || grados <= 45;
  static bool _calcularCrossShore(double grados) =>
      (grados > 45 && grados < 135) || (grados > 225 && grados < 315);

  bool get cacheExpirada =>
      DateTime.now().difference(actualizadoEn).inMinutes >= 30;
}

// ----------------------------------------------------------
// ENTIDAD: Ruta Trazada (Tabla RUTAS_TRAZADAS)
// ----------------------------------------------------------
class RutaTrazadaModel {
  final int? rutaId;
  final int usuarioId;
  final int spotId;
  final String? nombrePublico;
  final bool esPublica;
  final double distanciaKm;
  final int duracionMinutos;
  final double velocidadMedia;
  final double velocidadMaxima;
  final DateTime iniciadaEn;
  final DateTime? finalizadaEn;
  final List<CoordenadasRutaModel> coordenadas;

  const RutaTrazadaModel({
    this.rutaId,
    required this.usuarioId,
    required this.spotId,
    this.nombrePublico,
    this.esPublica = false,
    this.distanciaKm = 0.0,
    this.duracionMinutos = 0,
    this.velocidadMedia = 0.0,
    this.velocidadMaxima = 0.0,
    required this.iniciadaEn,
    this.finalizadaEn,
    this.coordenadas = const [],
  });

  Map<String, dynamic> toMap() => {
    'ruta_id': rutaId,
    'usuario_id': usuarioId,
    'spot_id': spotId,
    'nombre_publico': nombrePublico,
    'es_publica': esPublica ? 1 : 0,
    'distancia_total_km': distanciaKm,
    'duracion_minutos': duracionMinutos,
    'velocidad_media': velocidadMedia,
    'velocidad_maxima': velocidadMaxima,
    'iniciada_en': iniciadaEn.toIso8601String(),
    'finalizada_en': finalizadaEn?.toIso8601String(),
  };

  factory RutaTrazadaModel.fromMap(Map<String, dynamic> map) => RutaTrazadaModel(
    rutaId: map['ruta_id'] as int?,
    usuarioId: map['usuario_id'] as int,
    spotId: map['spot_id'] as int,
    nombrePublico: map['nombre_publico'] as String?,
    esPublica: (map['es_publica'] as int) == 1,
    distanciaKm: (map['distancia_total_km'] as num).toDouble(),
    duracionMinutos: map['duracion_minutos'] as int,
    velocidadMedia: (map['velocidad_media'] as num).toDouble(),
    velocidadMaxima: (map['velocidad_maxima'] as num? ?? 0).toDouble(),
    iniciadaEn: DateTime.parse(map['iniciada_en'] as String),
    finalizadaEn: map['finalizada_en'] != null
        ? DateTime.parse(map['finalizada_en'] as String)
        : null,
  );
}

// ----------------------------------------------------------
// ENTIDAD: Coordenadas (Tabla COORDENADAS_RUTA)
// ----------------------------------------------------------
class CoordenadasRutaModel {
  final int? coordenadaId;
  final int rutaId;
  final double latitud;
  final double longitud;
  final int secuencia;
  final DateTime timestamp;

  const CoordenadasRutaModel({
    this.coordenadaId,
    required this.rutaId,
    required this.latitud,
    required this.longitud,
    required this.secuencia,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'coordenada_id': coordenadaId,
    'ruta_id': rutaId,
    'latitud': latitud,
    'longitud': longitud,
    'secuencia': secuencia,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CoordenadasRutaModel.fromMap(Map<String, dynamic> map) =>
      CoordenadasRutaModel(
        coordenadaId: map['coordenada_id'] as int?,
        rutaId: map['ruta_id'] as int,
        latitud: (map['latitud'] as num).toDouble(),
        longitud: (map['longitud'] as num).toDouble(),
        secuencia: map['secuencia'] as int,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
