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

  // ─── INVITACIONES ──────────────────────────────────────

  /// Crear una invitación a una salida para un usuario por UID
  Future<void> crearInvitacion({required String salidaId, required String destinatarioId}) async {
    final emisor = AuthService.instance.usuarioActual;
    if (emisor == null) return;
    final invitacion = {
      'salida_id': salidaId,
      'emisor_id': emisor.googleId ?? emisor.usuarioId.toString(),
      'destinatario_id': destinatarioId,
      'creado_en': FieldValue.serverTimestamp(),
    };
    await _db.collection('invitaciones').add(invitacion);
    // TODO: enviar notificación push real vía FCM
    print('Push notification placeholder: invitación enviada a $destinatarioId');
  }

  /// Aceptar una invitación: se agrega al participante y se elimina la invitación
  Future<void> aceptarInvitacion(String invitacionId) async {
    final doc = await _db.collection('invitaciones').doc(invitacionId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final salidaId = data['salida_id'] as String;
    final usuario = AuthService.instance.usuarioActual;
    if (usuario == null) return;
    // añadir participante a la salida
    await anotarseEnSalida(salidaId, usuario);
    // eliminar la invitación
    await _db.collection('invitaciones').doc(invitacionId).delete();
  }

  /// Stream de invitaciones pendientes para un usuario (UID)
  Stream<List<InvitacionModel>> streamInvitacionesParaUsuario(String uid) {
    return _db.collection('invitaciones')
        .where('destinatario_id', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => InvitacionModel.fromDoc(d)).toList());
  }

  /// Helper: obtener perfil de usuario por UID (solo los campos necesarios)
  Future<UsuarioModel?> _obtenerUsuarioPorId(String uid) async {
    final snap = await _db.collection('usuarios').doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    return UsuarioModel(
      usuarioId: int.tryParse(uid) ?? 0,
      nombre: data['nombre'] as String,
      apellido: data['apellido'] as String,
      email: data['email'] as String,
      googleId: uid,
      avatarUrl: data['avatar_url'] as String?,
      nivelExperiencia: NivelUsuario.values.firstWhere((e) => e.name == data['nivel_experiencia'], orElse: () => NivelUsuario.iniciante),
    );
  }


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
        .snapshots()
        .asyncMap((snap) async {
          final salidas = <SalidaGrupal>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final esPublica = data['esPublica'] as bool? ?? true;
            final estado = data['estado'] as String? ?? 'abierta';
            if (esPublica && (estado == 'abierta' || estado == 'enCurso')) {
              final participantes = await _getParticipantes(doc.id);
              salidas.add(_salidaFromDoc(doc, participantes));
            }
          }
          // Ordenar localmente por fechaHora para evitar requerir un índice compuesto
          salidas.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
          return salidas;
        });
  }

  /// Stream de salidas de un usuario (organizador o participante)
  Stream<List<SalidaGrupal>> streamMisSalidas(String usuarioId) {
    return _db.collection('salidas')
        .snapshots()
        .asyncMap((snap) async {
          final salidas = <SalidaGrupal>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final estado = data['estado'] as String? ?? 'abierta';
            if (estado == 'cancelada') continue;
            final participantes = await _getParticipantes(doc.id);
            final esMio = data['organizadorId'] == usuarioId ||
                participantes.any((p) => p.usuarioId.toString() == usuarioId);
            if (esMio) {
              salidas.add(_salidaFromDoc(doc, participantes));
            }
          }
          // Ordenar localmente por fechaHora descendente
          salidas.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
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
        nivelExperiencia: NivelExperiencia.principiante,
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
