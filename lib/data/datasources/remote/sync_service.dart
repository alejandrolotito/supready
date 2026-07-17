import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../local/sup_database.dart';
import '../remote/auth_service.dart';
import '../../models/models.dart';

// ============================================================
// SUPReady - Sync Service (Offline-First)
// Sube rutas pendientes cuando vuelve la conexión
// ============================================================

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _firestore = FirebaseFirestore.instance;
  bool _sincronizando = false;

  /// Llamar al iniciar la app o al recuperar conexión
  Future<void> sincronizarPendientes() async {
    if (_sincronizando) return;
    final uid = AuthService.instance.usuarioActual?.googleId;
    if (uid == null) return;

    // Verificar conectividad
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    _sincronizando = true;
    try {
      final rutas = await SupDatabase.instance.getRutasSinSincronizar();
      for (final ruta in rutas) {
        if (ruta.rutaId == null || ruta.finalizadaEn == null) continue;
        await _subirRuta(uid, ruta);
        await SupDatabase.instance.marcarRutaSincronizada(ruta.rutaId!);
      }
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _subirRuta(String uid, RutaTrazadaModel ruta) async {
    final coords = await SupDatabase.instance.getCoordenadas(ruta.rutaId!);
    if (coords.isEmpty) return;

    // Crear sesión en Firestore
    final sessionRef = _firestore
        .collection('users').doc(uid)
        .collection('sessions').doc();

    await sessionRef.set({
      'startTime':      Timestamp.fromDate(ruta.iniciadaEn),
      'endTime':        Timestamp.fromDate(ruta.finalizadaEn!),
      'status':         'completed',
      'spotId':         ruta.spotId,
      'distanciaKm':    ruta.distanciaKm,
      'duracionMin':    ruta.duracionMinutos,
      'velocidadMedia': ruta.velocidadMedia,
      'velocidadMaxima':ruta.velocidadMaxima,
      'syncedAt':       FieldValue.serverTimestamp(),
    });

    // Subir coordenadas en batches de 500 (límite Firestore)
    final pointsRef = sessionRef.collection('points');
    for (int i = 0; i < coords.length; i += 500) {
      final batch = _firestore.batch();
      final chunk = coords.sublist(
          i, i + 500 > coords.length ? coords.length : i + 500);
      for (final c in chunk) {
        batch.set(pointsRef.doc(), {
          'latitude':  c.latitud,
          'longitude': c.longitud,
          'speed':     c.velocidadKmh / 3.6,
          'velKmh':    c.velocidadKmh,
          'sequence':  c.secuencia,
          'timestamp': Timestamp.fromDate(c.timestamp),
        });
      }
      await batch.commit();
    }
  }

  /// Escuchar cambios de conectividad y sincronizar automáticamente
  void iniciarEscucha() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        sincronizarPendientes();
      }
    });
  }
}
