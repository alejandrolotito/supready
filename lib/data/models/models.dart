// ============================================================
// SUPReady v3 - Modelos de Datos
// ============================================================

enum NivelExperiencia { principiante, intermedio, avanzado }
enum NivelUsuario { iniciante, intermedio, avanzado }
enum SupReadyIndex { verde, amarillo, rojo, sinDatos }

class UsuarioModel {
  final int? usuarioId;
  final String nombre, apellido, email;
  final String? googleId, avatarUrl;
  final NivelUsuario nivelExperiencia;

  const UsuarioModel({
    this.usuarioId, required this.nombre, required this.apellido,
    required this.email, this.googleId, this.avatarUrl,
    this.nivelExperiencia = NivelUsuario.iniciante,
  });

  String get nombreCompleto => '$nombre $apellido';

  Map<String, dynamic> toMap() => {
    'usuario_id': usuarioId, 'nombre': nombre, 'apellido': apellido,
    'email': email, 'google_id': googleId, 'avatar_url': avatarUrl,
    'nivel_experiencia': nivelExperiencia.name,
  };

  factory UsuarioModel.fromMap(Map<String, dynamic> m) => UsuarioModel(
    usuarioId: m['usuario_id'] as int?,
    nombre: m['nombre'] as String, apellido: m['apellido'] as String,
    email: m['email'] as String, googleId: m['google_id'] as String?,
    avatarUrl: m['avatar_url'] as String?,
    nivelExperiencia: NivelUsuario.values.firstWhere(
      (e) => e.name == m['nivel_experiencia'], orElse: () => NivelUsuario.iniciante),
  );
}

class SpotModel {
  final int? spotId;
  final String nombre;
  final double latitud, longitud;
  final String descripcion;
  final CondicionesClimaticasModel? condiciones;
  final bool esFavorito;

  const SpotModel({
    this.spotId, required this.nombre, required this.latitud,
    required this.longitud, this.descripcion = '', this.condiciones,
    this.esFavorito = false,
  });

  SupReadyIndex get indiceViabilidad {
    final c = condiciones;
    if (c == null) return SupReadyIndex.sinDatos;
    if (c.vientoKts > 15 || c.rafagasKts > 18 || c.olasMetros > 1.0 || c.esOffshore) {
      return SupReadyIndex.rojo;
    }
    if (c.vientoKts >= 9 || c.esCrossShore || c.olasMetros >= 0.5) {
      return SupReadyIndex.amarillo;
    }
    return SupReadyIndex.verde;
  }

  Map<String, dynamic> toMap() => {
    'spot_id': spotId, 'nombre': nombre, 'latitud': latitud,
    'longitud': longitud, 'descripcion': descripcion,
    'es_favorito': esFavorito ? 1 : 0,
  };

  factory SpotModel.fromMap(Map<String, dynamic> m) => SpotModel(
    spotId: m['spot_id'] as int?, nombre: m['nombre'] as String,
    latitud: (m['latitud'] as num).toDouble(), longitud: (m['longitud'] as num).toDouble(),
    descripcion: m['descripcion'] as String? ?? '',
    esFavorito: (m['es_favorito'] as int? ?? 0) == 1,
  );

  SpotModel copyWith({CondicionesClimaticasModel? condiciones, bool? esFavorito}) => SpotModel(
    spotId: spotId, nombre: nombre, latitud: latitud, longitud: longitud,
    descripcion: descripcion,
    condiciones: condiciones ?? this.condiciones,
    esFavorito: esFavorito ?? this.esFavorito,
  );
}

class CondicionesClimaticasModel {
  final double vientoKts, rafagasKts, olasMetros, dirVientoGrados;
  final bool esOffshore, esCrossShore;
  final double? tempAguaC;
  final DateTime actualizadoEn;

  const CondicionesClimaticasModel({
    required this.vientoKts, required this.rafagasKts, required this.olasMetros,
    required this.dirVientoGrados, required this.esOffshore, required this.esCrossShore,
    this.tempAguaC, required this.actualizadoEn,
  });

  bool get cacheExpirada =>
      DateTime.now().difference(actualizadoEn).inMinutes >= 30;

  String get dirVientoTexto {
    final d = dirVientoGrados;
    if (d < 22.5 || d >= 337.5) return 'N';
    if (d < 67.5) return 'NE';
    if (d < 112.5) return 'E';
    if (d < 157.5) return 'SE';
    if (d < 202.5) return 'S';
    if (d < 247.5) return 'SO';
    if (d < 292.5) return 'O';
    return 'NO';
  }
}

class RutaTrazadaModel {
  final int? rutaId, usuarioId, spotId;
  final String? nombrePublico;
  final bool esPublica;
  final double distanciaKm, velocidadMedia, velocidadMaxima;
  final int duracionMinutos;
  final DateTime iniciadaEn;
  final DateTime? finalizadaEn;
  final List<CoordenadasRutaModel> coordenadas;

  const RutaTrazadaModel({
    this.rutaId, required this.usuarioId, required this.spotId,
    this.nombrePublico, this.esPublica = false,
    this.distanciaKm = 0.0, this.duracionMinutos = 0,
    this.velocidadMedia = 0.0, this.velocidadMaxima = 0.0,
    required this.iniciadaEn, this.finalizadaEn,
    this.coordenadas = const [],
  });

  Map<String, dynamic> toMap() => {
    'ruta_id': rutaId, 'usuario_id': usuarioId ?? 0, 'spot_id': spotId ?? 0,
    'nombre_publico': nombrePublico, 'es_publica': esPublica ? 1 : 0,
    'distancia_total_km': distanciaKm, 'duracion_minutos': duracionMinutos,
    'velocidad_media': velocidadMedia, 'velocidad_maxima': velocidadMaxima,
    'iniciada_en': iniciadaEn.toIso8601String(),
    'finalizada_en': finalizadaEn?.toIso8601String(),
  };

  factory RutaTrazadaModel.fromMap(Map<String, dynamic> m) => RutaTrazadaModel(
    rutaId: m['ruta_id'] as int?, usuarioId: m['usuario_id'] as int,
    spotId: m['spot_id'] as int,
    nombrePublico: m['nombre_publico'] as String?,
    esPublica: (m['es_publica'] as int? ?? 0) == 1,
    distanciaKm: (m['distancia_total_km'] as num).toDouble(),
    duracionMinutos: m['duracion_minutos'] as int,
    velocidadMedia: (m['velocidad_media'] as num).toDouble(),
    velocidadMaxima: (m['velocidad_maxima'] as num? ?? 0).toDouble(),
    iniciadaEn: DateTime.parse(m['iniciada_en'] as String),
    finalizadaEn: m['finalizada_en'] != null ? DateTime.parse(m['finalizada_en'] as String) : null,
  );
}

class CoordenadasRutaModel {
  final int? coordenadaId, rutaId;
  final double latitud, longitud;
  final int secuencia;
  final double velocidadKmh; // velocidad real en ese punto
  final DateTime timestamp;

  const CoordenadasRutaModel({
    this.coordenadaId, required this.rutaId, required this.latitud,
    required this.longitud, required this.secuencia,
    this.velocidadKmh = 0.0, required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'coordenada_id': coordenadaId, 'ruta_id': rutaId ?? 0,
    'latitud': latitud, 'longitud': longitud, 'secuencia': secuencia,
    'velocidad_kmh': velocidadKmh,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CoordenadasRutaModel.fromMap(Map<String, dynamic> m) => CoordenadasRutaModel(
    coordenadaId: m['coordenada_id'] as int?, rutaId: m['ruta_id'] as int,
    latitud: (m['latitud'] as num).toDouble(), longitud: (m['longitud'] as num).toDouble(),
    secuencia: m['secuencia'] as int,
    velocidadKmh: (m['velocidad_kmh'] as num? ?? 0).toDouble(),
    timestamp: DateTime.parse(m['timestamp'] as String),
  );
}

// ─── SALIDAS GRUPALES ─────────────────────────────────────────

enum NivelSalida { todos, principiante, intermedio, avanzado }
enum EstadoSalida { abierta, enCurso, finalizada, cancelada }
enum EstadoParticipante { confirmado, enEspera, remando, finalizado }

class SalidaGrupal {
  final int? salidaId;
  final String? firestoreId;
  final int organizadorId;
  final int spotId;
  final String spotNombre;
  final DateTime fechaHora;
  final NivelSalida nivelMinimo;
  final int cuposMax;
  final bool esPublica;
  final EstadoSalida estado;
  final String descripcion;
  final List<ParticipanteSalida> participantes;

  const SalidaGrupal({
    this.salidaId,
    this.firestoreId,
    required this.organizadorId,
    required this.spotId,
    required this.spotNombre,
    required this.fechaHora,
    this.nivelMinimo = NivelSalida.todos,
    this.cuposMax = 10,
    this.esPublica = true,
    this.estado = EstadoSalida.abierta,
    this.descripcion = '',
    this.participantes = const [],
  });

  int get cuposDisponibles => cuposMax - participantes.length;
  bool get llena => cuposDisponibles <= 0;
  bool get activa => estado == EstadoSalida.abierta || estado == EstadoSalida.enCurso;

  Map<String, dynamic> toMap() => {
    'salida_id': salidaId,
    'organizador_id': organizadorId,
    'spot_id': spotId,
    'spot_nombre': spotNombre,
    'fecha_hora': fechaHora.toIso8601String(),
    'nivel_minimo': nivelMinimo.name,
    'cupos_max': cuposMax,
    'es_publica': esPublica ? 1 : 0,
    'estado': estado.name,
    'descripcion': descripcion,
  };

  factory SalidaGrupal.fromMap(Map<String, dynamic> m) => SalidaGrupal(
    salidaId: m['salida_id'] as int?,
    organizadorId: m['organizador_id'] as int,
    spotId: m['spot_id'] as int,
    spotNombre: m['spot_nombre'] as String? ?? '',
    fechaHora: DateTime.parse(m['fecha_hora'] as String),
    nivelMinimo: NivelSalida.values.firstWhere(
        (e) => e.name == m['nivel_minimo'], orElse: () => NivelSalida.todos),
    cuposMax: m['cupos_max'] as int? ?? 10,
    esPublica: (m['es_publica'] as int? ?? 1) == 1,
    estado: EstadoSalida.values.firstWhere(
        (e) => e.name == m['estado'], orElse: () => EstadoSalida.abierta),
    descripcion: m['descripcion'] as String? ?? '',
  );
}

class ParticipanteSalida {
  final int usuarioId;
  final String nombre;
  final String? avatarUrl;
  final EstadoParticipante estado;

  const ParticipanteSalida({
    required this.usuarioId,
    required this.nombre,
    this.avatarUrl,
    this.estado = EstadoParticipante.confirmado,
  });
}

// ─── INVITACIÓN SALIDA ──────────────────────────────────────
class InvitacionModel {
  final String invitacionId; // Firestore doc ID
  final String salidaId; // Firestore salida doc ID
  final String emisorId; // UID of who sent the invitation (organizador)
  final String destinatarioId; // UID of invited user
  final DateTime creadoEn;

  const InvitacionModel({
    required this.invitacionId,
    required this.salidaId,
    required this.emisorId,
    required this.destinatarioId,
    required this.creadoEn,
  });

  Map<String, dynamic> toMap() => {
        'salida_id': salidaId,
        'emisor_id': emisorId,
        'destinatario_id': destinatarioId,
        'creado_en': FieldValue.serverTimestamp(),
      };

  factory InvitacionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return InvitacionModel(
      invitacionId: doc.id,
      salidaId: d['salida_id'] as String,
      emisorId: d['emisor_id'] as String,
      destinatarioId: d['destinatario_id'] as String,
      creadoEn: (d['creado_en'] as Timestamp).toDate(),
    );
  }


}

extension SalidaGrupalExt on SalidaGrupal {
  SalidaGrupal copyWithParticipantes(List<ParticipanteSalida> participantes) =>
      SalidaGrupal(
        salidaId: salidaId, firestoreId: firestoreId, organizadorId: organizadorId,
        spotId: spotId, spotNombre: spotNombre, fechaHora: fechaHora,
        nivelMinimo: nivelMinimo, cuposMax: cuposMax,
        esPublica: esPublica, estado: estado, descripcion: descripcion,
        participantes: participantes,
      );
}
