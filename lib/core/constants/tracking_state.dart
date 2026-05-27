import 'package:flutter/foundation.dart';
import '../../data/datasources/local/tracking_service.dart';
import '../../data/models/models.dart';

// ============================================================
// SUPReady - Estado global de tracking
// Sobrevive cambios de tab y navegación interna.
// Todos los widgets que muestren info de la remada activa
// escuchan este notifier en lugar del stream directo.
// ============================================================

class TrackingState extends ChangeNotifier {
  static final TrackingState instance = TrackingState._();
  TrackingState._() {
    // Escuchar métricas del servicio y re-notificar a la UI
    TrackingService.instance.metricasStream.listen((m) {
      _metricas = m;
      notifyListeners();
    });
    TrackingService.instance.estadoStream.listen((e) {
      _estado = e;
      notifyListeners();
    });
    TrackingService.instance.coordenadaStream.listen((c) {
      _coordenadas.add(c);
      notifyListeners();
    });
  }

  EstadoTracking _estado = EstadoTracking.inactivo;
  MetricasTracking? _metricas;
  final List<CoordenadasRutaModel> _coordenadas = [];

  EstadoTracking get estado => _estado;
  MetricasTracking? get metricas => _metricas;
  List<CoordenadasRutaModel> get coordenadas => List.unmodifiable(_coordenadas);
  bool get activo => _estado == EstadoTracking.activo;

  void resetCoordenadas() => _coordenadas.clear();
}
