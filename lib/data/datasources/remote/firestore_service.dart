import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/models.dart';


// ============================================================
// SUPReady - Firestore Service (multiusuario en tiempo real)
// Colecciones:
//   /salidas          → salidas grupales públicas
//   /salidas/{id}/participantes → sub-colección
//   /salidas/{id}/mensajes      → chat en tiempo real
//   /usuarios/{uid}             → perfiles públicos
// Rutas GPS siguen en SQLite local (privadas por usuario)
// ============================================================

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ─── SALIDAS ──────────────────────────────────────────────

  /// Crear salida → devuelve el ID generado por Firestore
  Future<String> crearSalida(SalidaGrupal salida, String autorNombre) async {
    final doc = await _db.collection('salidas').add({
      'organizadorId':  salida.organizadorId.toString(),
      'organizadorNombre': autorNombre,
      'spotId':         salida.spotId,
      'spotNombre':     salida.spotNombre,
      'fechaHora':      Timestamp.fromDate(salida.fechaHora),
      'nivelMinimo':    salida.nivelMinimo.name,
      'cuposMax':       salida.cuposMax,
      'esPublica':      salida.esPublica,
      'estado':         salida.estado.name,
      'descripcion':    salida.descripcion,
      'creadoEn':       FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Stream de salidas públicas activas (tiempo real)
  Stream<List<SalidaGrupal>> streamSalidasPublicas() {
    return _db.collection('salidas')
        .where('esPublica', isEqualTo: true)
        .where('estado', whereIn: ['abierta', 'enCurso'])
        .orderBy('fechaHora')
        .snapshots()
        .asyncMap((snap) async {
          final salidas = <SalidaGrupal>[];
          for (final doc in snap.docs) {
            final participantes = await _getParticipantes(doc.id);
            salidas.add(_salidaFromDoc(doc, participantes));
          }
          return salidas;
        });
  }

  /// Stream de salidas de un usuario (organizador o participante)
  Stream<List<SalidaGrupal>> streamMisSalidas(String usuarioId) {
    return _db.collection('salidas')
        .where('estado', whereNotIn: ['cancelada'])
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final salidas = <SalidaGrupal>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final participantes = await _getParticipantes(doc.id);
            final esMio = data['organizadorId'] == usuarioId ||
                participantes.any((p) => p.usuarioId.toString() == usuarioId);
            if (esMio) salidas.add(_salidaFromDoc(doc, participantes));
          }
          return salidas;
        });
  }

  /// Anotarse a una salida
  Future<void> anotarseEnSalida(String salidaId, UsuarioModel usuario) async {
    await _db
        .collection('salidas')
        .doc(salidaId)
        .collection('participantes')
        .doc(usuario.googleId ?? usuario.usuarioId.toString())
        .set({
      'usuarioId':  usuario.googleId ?? usuario.usuarioId.toString(),
      'nombre':     usuario.nombre,
      'avatarUrl':  usuario.avatarUrl,
      'estado':     'confirmado',
      'anotadoEn':  FieldValue.serverTimestamp(),
    });
  }

  /// Cancelar salida
  Future<void> cancelarSalida(String salidaId) async {
    await _db.collection('salidas').doc(salidaId)
        .update({'estado': 'cancelada'});
  }

  Future<List<ParticipanteSalida>> _getParticipantes(String salidaId) async {
    final snap = await _db
        .collection('salidas').doc(salidaId)
        .collection('participantes').get();
    return snap.docs.map((d) => ParticipanteSalida(
      usuarioId: int.tryParse(d.data()['usuarioId']?.toString() ?? '0') ?? 0,
      nombre: d.data()['nombre'] ?? '',
      avatarUrl: d.data()['avatarUrl'],
      estado: EstadoParticipante.values.firstWhere(
          (e) => e.name == d.data()['estado'],
          orElse: () => EstadoParticipante.confirmado),
    )).toList();
  }

  SalidaGrupal _salidaFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      List<ParticipanteSalida> participantes) {
    final d = doc.data()!;
    return SalidaGrupal(
      salidaId:    int.tryParse(doc.id.hashCode.toString()),
      firestoreId: doc.id,
      organizadorId: int.tryParse(d['organizadorId']?.toString() ?? '0') ?? 0,
      spotId:      d['spotId'] as int? ?? 0,
      spotNombre:  d['spotNombre'] as String? ?? '',
      fechaHora:   (d['fechaHora'] as Timestamp).toDate(),
      nivelMinimo: NivelSalida.values.firstWhere(
          (e) => e.name == d['nivelMinimo'],
          orElse: () => NivelSalida.todos),
      cuposMax:    d['cuposMax'] as int? ?? 10,
      esPublica:   d['esPublica'] as bool? ?? true,
      estado:      EstadoSalida.values.firstWhere(
          (e) => e.name == d['estado'],
          orElse: () => EstadoSalida.abierta),
      descripcion: d['descripcion'] as String? ?? '',
      participantes: participantes,
    );
  }

  // ─── CHAT EN TIEMPO REAL ──────────────────────────────────

  /// Stream de mensajes de una salida (tiempo real)
  Stream<List<MensajeChat>> streamMensajes(String salidaId) {
    return _db
        .collection('salidas').doc(salidaId)
        .collection('mensajes')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs.map((d) => MensajeChat(
              id:        d.id,
              autorId:   d.data()['autorId'] ?? '',
              autorNombre: d.data()['autorNombre'] ?? '',
              avatarUrl: d.data()['avatarUrl'],
              texto:     d.data()['texto'] ?? '',
              timestamp: (d.data()['timestamp'] as Timestamp?)?.toDate()
                  ?? DateTime.now(),
            )).toList());
  }

  /// Enviar mensaje
  Future<void> enviarMensaje(String salidaId, UsuarioModel autor, String texto) async {
    await _db
        .collection('salidas').doc(salidaId)
        .collection('mensajes')
        .add({
      'autorId':     autor.googleId ?? autor.usuarioId.toString(),
      'autorNombre': autor.nombre,
      'avatarUrl':   autor.avatarUrl,
      'texto':       texto,
      'timestamp':   FieldValue.serverTimestamp(),
    });
  }

  // ─── PERFIL PÚBLICO ───────────────────────────────────────
  Future<void> upsertPerfil(UsuarioModel u) async {
    final id = u.googleId ?? u.email;
    await _db.collection('usuarios').doc(id).set({
      'nombre':    u.nombre,
      'apellido':  u.apellido,
      'avatarUrl': u.avatarUrl,
      'nivel':     u.nivelExperiencia.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    }
/// Genera colecciones y documentos iniciales si no existen
  Future<void> generarTablasIniciales() async {
    // Salidas: crear una salida de ejemplo si la colección está vacía
    final salidasSnap = await _db.collection('salidas').limit(1).get();
    if (salidasSnap.docs.isEmpty) {
      await crearSalida(
        SalidaGrupal(
          salidaId: 0,
          firestoreId: '',
          organizadorId: 0,
          spotId: 0,
          spotNombre: 'Ejemplo Spot',
          fechaHora: DateTime.now().add(const Duration(hours: 1)),
          nivelMinimo: NivelSalida.todos,
          cuposMax: 10,
          esPublica: true,
          estado: EstadoSalida.abierta,
          descripcion: 'Salida de ejemplo creada automáticamente.',
          participantes: [],
        ),
        'OrganizadorDemo',
      );
    }

    // Usuarios: crear un usuario de ejemplo si la colección está vacía
    final usuariosSnap = await _db.collection('usuarios').limit(1).get();
    if (usuariosSnap.docs.isEmpty) {
      await upsertPerfil(UsuarioModel(
        googleId: null,
        usuarioId: 0,
        email: 'demo@example.com',
        nombre: 'Demo',
        apellido: 'Usuario',
        avatarUrl: '',
        nivelExperiencia: NivelUsuario.iniciante,
      ));
    }
  }




}
// ─── DTO mensaje de chat ──────────────────────────────────────
class MensajeChat {
  final String id, autorId, autorNombre, texto;
  final String? avatarUrl;
  final DateTime timestamp;
  const MensajeChat({
    required this.id, required this.autorId,
    required this.autorNombre, required this.texto,
    this.avatarUrl, required this.timestamp,
  });
}
