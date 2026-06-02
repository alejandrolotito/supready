import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import '../../models/models.dart';

// ============================================================
// SUPReady v2.0 - Firestore Service (spec-compliant)
// Schema:
//   /users/{uid}                    → perfil + favoriteSpotId
//   /users/{uid}/sessions/{id}      → remadas (tracking cloud)
//   /users/{uid}/sessions/{id}/points → GPS points (WriteBatch)
//   /spots/{spotId}                 → spots públicos + currentConditions
//   /group_trips/{tripId}           → salidas grupales (spec: group_trips)
//   /group_trips/{tripId}/messages  → chat (solo attendees)
// ============================================================

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ─── USUARIOS ─────────────────────────────────────────────

  Future<void> upsertPerfil(UsuarioModel u) async {
    final id = u.googleId ?? u.email;
    await _db.collection('users').doc(id).set({
      'name':     u.nombre,
      'email':    u.email,
      'photoUrl': u.avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setFavoriteSpot(String uid, String spotId) async {
    await _db.collection('users').doc(uid).update({'favoriteSpotId': spotId});
  }

  Stream<Map<String, dynamic>?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots()
        .map((d) => d.data());
  }

  // ─── SPOTS ────────────────────────────────────────────────

  Future<String> crearSpot({
    required String nombre,
    required double lat,
    required double lng,
    required String creadorId,
  }) async {
    final doc = await _db.collection('spots').add({
      'name':      nombre,
      'location':  GeoPoint(lat, lng),
      'createdBy': creadorId,
      'isPublic':  true,
      'currentConditions': {
        'temperature':      22.0,
        'windSpeedKnots':   0.0,
        'windDirectionStr': 'N',
        'tideHeight':       0.0,
        'tideTrend':        'ESTABLE',
        'lastUpdated':      FieldValue.serverTimestamp(),
      },
    });
    return doc.id;
  }

  Stream<List<SpotFirestore>> streamSpots() {
    return _db.collection('spots')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(SpotFirestore.fromDoc).toList());
  }

  Stream<SpotFirestore?> streamSpot(String spotId) {
    return _db.collection('spots').doc(spotId).snapshots()
        .map((d) => d.exists ? SpotFirestore.fromDoc(d) : null);
  }

  Future<void> actualizarCondiciones(
      String spotId, Map<String, dynamic> condiciones) async {
    await _db.collection('spots').doc(spotId).update({
      'currentConditions': {
        ...condiciones,
        'lastUpdated': FieldValue.serverTimestamp(),
      }
    });
  }

  // ─── GROUP TRIPS (spec: /group_trips) ────────────────────

  Future<String> crearSalida(SalidaGrupal salida, String autorNombre) async {
    final uid = AuthService.instance.usuarioActual?.googleId
        ?? AuthService.instance.usuarioActual?.usuarioId.toString()
        ?? '';
    final doc = await _db.collection('group_trips').add({
      'title':           salida.spotNombre,
      'description':     salida.descripcion,
      'organizerId':     uid,
      'organizerName':   autorNombre,
      'date':            Timestamp.fromDate(salida.fechaHora),
      'maxParticipants': salida.cuposMax,
      'status':          'open',
      'attendees':       [uid],   // organizador es el primer attendee
      'nivelMinimo':     salida.nivelMinimo.name,
      'spotId':          salida.spotId,
      'spotNombre':      salida.spotNombre,
      'isPublic':        salida.esPublica,
      'createdAt':       FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<List<SalidaGrupal>> streamSalidasPublicas() {
    return _db.collection('group_trips')
        .where('isPublic', isEqualTo: true)
        .where('status', isEqualTo: 'open')
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map(_salidaFromDoc).toList());
  }

  Stream<List<SalidaGrupal>> streamMisSalidas(String uid) {
    // Salidas donde el usuario es attendee
    return _db.collection('group_trips')
        .where('attendees', arrayContains: uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_salidaFromDoc).toList());
  }

  /// Anotarse: agrega uid al array attendees (Firestore arrayUnion)
  Future<void> anotarseEnSalida(String tripId, UsuarioModel usuario) async {
    final uid = usuario.googleId ?? usuario.usuarioId.toString();
    await _db.collection('group_trips').doc(tripId).update({
      'attendees': FieldValue.arrayUnion([uid]),
    });
    // También actualizar perfil público
    await upsertPerfil(usuario);
  }

  Future<void> cancelarSalida(String tripId) async {
    await _db.collection('group_trips').doc(tripId)
        .update({'status': 'cancelled'});
  }

  SalidaGrupal _salidaFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final attendees = (d['attendees'] as List?)?.cast<String>() ?? [];
    return SalidaGrupal(
      firestoreId:  doc.id,
      organizadorId: 0,
      spotId:       d['spotId'] as int? ?? 0,
      spotNombre:   d['spotNombre'] as String? ?? d['title'] as String? ?? '',
      fechaHora:    (d['date'] as Timestamp).toDate(),
      nivelMinimo:  NivelSalida.values.firstWhere(
          (e) => e.name == d['nivelMinimo'],
          orElse: () => NivelSalida.todos),
      cuposMax:     d['maxParticipants'] as int? ?? 10,
      esPublica:    d['isPublic'] as bool? ?? true,
      estado:       _estadoFromStatus(d['status'] as String? ?? 'open'),
      descripcion:  d['description'] as String? ?? '',
      participantes: attendees.map((uid) => ParticipanteSalida(
        usuarioId: 0, nombre: uid,
        estado: EstadoParticipante.confirmado,
      )).toList(),
    );
  }

  EstadoSalida _estadoFromStatus(String s) => const {
    'open':      EstadoSalida.abierta,
    'active':    EstadoSalida.enCurso,
    'completed': EstadoSalida.finalizada,
    'cancelled': EstadoSalida.cancelada,
  }[s] ?? EstadoSalida.abierta;

  // ─── CHAT (solo attendees, spec: messages subcolección) ──

  Stream<List<MensajeChat>> streamMensajes(String tripId) {
    return _db
        .collection('group_trips').doc(tripId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs.map((d) => MensajeChat(
              id:          d.id,
              autorId:     d.data()['senderId'] ?? '',
              autorNombre: d.data()['senderName'] ?? 'Palista',
              avatarUrl:   d.data()['avatarUrl'],
              texto:       d.data()['text'] ?? '',
              timestamp:   (d.data()['timestamp'] as Timestamp?)?.toDate()
                  ?? DateTime.now(),
            )).toList());
  }

  Future<void> enviarMensaje(
      String tripId, UsuarioModel autor, String texto) async {
    final uid = autor.googleId ?? autor.usuarioId.toString();
    await _db
        .collection('group_trips').doc(tripId)
        .collection('messages')
        .add({
      'senderId':   uid,
      'senderName': autor.nombre,
      'avatarUrl':  autor.avatarUrl,
      'text':       texto,
      'timestamp':  FieldValue.serverTimestamp(),
    });
  }
}

// ─── DTOs ─────────────────────────────────────────────────────

class SpotFirestore {
  final String id, name;
  final GeoPoint location;
  final double windSpeedKnots, temperature, tideHeight;
  final String windDirectionStr, tideTrend;
  final bool isPublic;
  final String createdBy;

  const SpotFirestore({
    required this.id, required this.name, required this.location,
    required this.windSpeedKnots, required this.temperature,
    required this.tideHeight, required this.windDirectionStr,
    required this.tideTrend, required this.isPublic,
    required this.createdBy,
  });

  factory SpotFirestore.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final wx = d['currentConditions'] as Map<String, dynamic>? ?? {};
    return SpotFirestore(
      id:               doc.id,
      name:             d['name'] as String? ?? '',
      location:         d['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      windSpeedKnots:   (wx['windSpeedKnots'] ?? 0.0).toDouble(),
      temperature:      (wx['temperature'] ?? 0.0).toDouble(),
      tideHeight:       (wx['tideHeight'] ?? 0.0).toDouble(),
      windDirectionStr: wx['windDirectionStr'] as String? ?? 'N',
      tideTrend:        wx['tideTrend'] as String? ?? 'ESTABLE',
      isPublic:         d['isPublic'] as bool? ?? true,
      createdBy:        d['createdBy'] as String? ?? '',
    );
  }

  /// SUP Ready Index según condiciones actuales
  String get supReadyIndex {
    if (windSpeedKnots > 15) return 'rojo';
    if (windSpeedKnots >= 9)  return 'amarillo';
    return 'verde';
  }
}

class MensajeChat {
  final String id, autorId, autorNombre, texto;
  final String? avatarUrl;
  final DateTime timestamp;
  const MensajeChat({
    required this.id, required this.autorId, required this.autorNombre,
    required this.texto, this.avatarUrl, required this.timestamp,
  });
}
