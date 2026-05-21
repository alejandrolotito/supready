import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supready/data/datasources/local/sup_database.dart';

// ============================================================
// SUPReady - Servicio de Sincronización
// ERS RF3.3: Sync JSON automático al detectar restauración de datos
// ERS CU01 (Flujo alterno 3.a): Caché local con banner advertencia
// ============================================================

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _sincronizando = false;

  final _syncController = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get syncStream => _syncController.stream;

  // Inicia escucha de conectividad
  void iniciar() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final tieneInternet = results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);

      if (tieneInternet && !_sincronizando) {
        _sincronizarPendientes();
      }
    });
  }

  Future<void> _sincronizarPendientes() async {
    _sincronizando = true;
    _syncController.add(SyncEvent.iniciando());

    try {
      final rutasPendientes = await SupDatabase.instance.getRutasSinSincronizar();

      if (rutasPendientes.isEmpty) {
        _syncController.add(SyncEvent.sinPendientes());
        _sincronizando = false;
        return;
      }

      int sincronizadas = 0;
      for (final ruta in rutasPendientes) {
        try {
          // TODO: POST a API backend con ruta + coordenadas
          // await _apiClient.subirRuta(ruta);
          await SupDatabase.instance.marcarRutaSincronizada(ruta.rutaId!);
          sincronizadas++;
        } catch (e) {
          // Si falla una ruta, continúa con las demás
          continue;
        }
      }

      _syncController.add(SyncEvent.completado(sincronizadas));
    } catch (e) {
      _syncController.add(SyncEvent.error(e.toString()));
    } finally {
      _sincronizando = false;
    }
  }

  // Verificar conectividad actual
  Future<bool> tieneConectividad() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  void detener() {
    _connectivitySub?.cancel();
  }

  void dispose() {
    detener();
    _syncController.close();
  }
}

// ----------------------------------------------------------
// Eventos de sincronización
// ----------------------------------------------------------
class SyncEvent {
  final SyncEstado estado;
  final int? cantidad;
  final String? error;

  const SyncEvent._({required this.estado, this.cantidad, this.error});

  factory SyncEvent.iniciando()           => const SyncEvent._(estado: SyncEstado.iniciando);
  factory SyncEvent.sinPendientes()       => const SyncEvent._(estado: SyncEstado.sinPendientes);
  factory SyncEvent.completado(int n)     => SyncEvent._(estado: SyncEstado.completado, cantidad: n);
  factory SyncEvent.error(String msg)     => SyncEvent._(estado: SyncEstado.error, error: msg);
}

enum SyncEstado { iniciando, sinPendientes, completado, error }
