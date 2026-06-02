import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/firestore_service.dart';
import '../../data/datasources/remote/auth_service.dart';
import '../../data/models/models.dart';

// ============================================================
// SUPReady - Riverpod Providers (spec v1.5)
// ============================================================

final authProvider = Provider<AuthService>((ref) => AuthService.instance);

final usuarioActualProvider = Provider<UsuarioModel?>((ref) {
  return AuthService.instance.usuarioActual;
});

final spotsProvider = StreamProvider<List<SpotFirestore>>((ref) {
  return FirestoreService.instance.streamSpots();
});

final spotProvider = StreamProvider.family<SpotFirestore?, String>((ref, spotId) {
  return FirestoreService.instance.streamSpot(spotId);
});

final salidasPublicasProvider = StreamProvider<List<SalidaGrupal>>((ref) {
  return FirestoreService.instance.streamSalidasPublicas();
});

final misSalidasProvider =
    StreamProvider.family<List<SalidaGrupal>, String>((ref, uid) {
  return FirestoreService.instance.streamMisSalidas(uid);
});

final chatProvider =
    StreamProvider.family<List<MensajeChat>, String>((ref, tripId) {
  return FirestoreService.instance.streamMensajes(tripId);
});

final userProfileProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  return FirestoreService.instance.streamUserProfile(uid);
});
