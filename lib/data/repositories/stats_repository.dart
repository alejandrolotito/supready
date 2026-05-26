import '../datasources/local/sup_database.dart';
import '../models/models.dart';

// ============================================================
// SUPReady - Estadísticas calculadas desde SQLite
// ============================================================

class StatsRepository {
  static final StatsRepository instance = StatsRepository._();
  StatsRepository._();

  Future<EstadisticasUsuario> calcular(int? usuarioId) async {
    final rutas = usuarioId != null
        ? await SupDatabase.instance.getRutasPorUsuario(usuarioId)
        : await SupDatabase.instance.getAllRutas();

    if (rutas.isEmpty) return EstadisticasUsuario.vacio();

    final completas = rutas.where((r) => r.finalizadaEn != null).toList();
    final totalKm   = completas.fold(0.0, (s, r) => s + r.distanciaKm);
    final totalMin  = completas.fold(0, (s, r) => s + r.duracionMinutos);
    final velMedia  = completas.isEmpty ? 0.0
        : completas.fold(0.0, (s, r) => s + r.velocidadMedia) / completas.length;
    final velMax    = completas.isEmpty ? 0.0
        : completas.map((r) => r.velocidadMaxima).reduce((a, b) => a > b ? a : b);

    // Racha de días consecutivos
    final dias = completas.map((r) =>
        DateTime(r.iniciadaEn.year, r.iniciadaEn.month, r.iniciadaEn.day)).toSet().toList()
      ..sort();
    int racha = 0, rachaMax = 0, rachaActual = 1;
    for (int i = 1; i < dias.length; i++) {
      if (dias[i].difference(dias[i-1]).inDays == 1) {
        rachaActual++;
        if (rachaActual > rachaMax) rachaMax = rachaActual;
      } else {
        rachaActual = 1;
      }
    }
    // Racha actual (desde hoy hacia atrás)
    final hoy = DateTime.now();
    if (dias.isNotEmpty) {
      final ultimo = dias.last;
      if (hoy.difference(ultimo).inDays <= 1) {
        racha = rachaActual;
      }
    }

    // Mes actual
    final mesActual = completas.where((r) =>
        r.iniciadaEn.month == DateTime.now().month &&
        r.iniciadaEn.year == DateTime.now().year).toList();

    return EstadisticasUsuario(
      totalRutas: completas.length,
      totalKm: totalKm,
      totalMinutos: totalMin,
      velocidadMedia: velMedia,
      velocidadMaxima: velMax,
      rachaActualDias: racha,
      rachaMaxDias: rachaMax,
      rutasMes: mesActual.length,
      kmMes: mesActual.fold(0.0, (s, r) => s + r.distanciaKm),
    );
  }
}

class EstadisticasUsuario {
  final int totalRutas, totalMinutos, rachaActualDias, rachaMaxDias, rutasMes;
  final double totalKm, velocidadMedia, velocidadMaxima, kmMes;

  const EstadisticasUsuario({
    required this.totalRutas, required this.totalKm, required this.totalMinutos,
    required this.velocidadMedia, required this.velocidadMaxima,
    required this.rachaActualDias, required this.rachaMaxDias,
    required this.rutasMes, required this.kmMes,
  });

  factory EstadisticasUsuario.vacio() => const EstadisticasUsuario(
    totalRutas: 0, totalKm: 0, totalMinutos: 0, velocidadMedia: 0,
    velocidadMaxima: 0, rachaActualDias: 0, rachaMaxDias: 0, rutasMes: 0, kmMes: 0);

  String get totalKmStr => '${totalKm.toStringAsFixed(1)} km';
  String get velMediaStr => '${velocidadMedia.toStringAsFixed(1)} km/h';
  String get velMaxStr => '${velocidadMaxima.toStringAsFixed(1)} km/h';
  String get tiempoTotalStr {
    final h = totalMinutos ~/ 60, m = totalMinutos % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
