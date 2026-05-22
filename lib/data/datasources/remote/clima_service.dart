import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/models.dart';

// ============================================================
// SUPReady - Servicio de Clima Marítimo
// Open-Meteo Marine API — gratuita, sin API key
// https://marine-api.open-meteo.com
// Refresco: cada 30 min por spot (cache local)
// ============================================================

class ClimaService {
  static final ClimaService instance = ClimaService._();
  ClimaService._();

  static const _baseUrl = 'https://marine-api.open-meteo.com/v1/marine';
  static const _windUrl = 'https://api.open-meteo.com/v1/forecast';

  // Cache en memoria: spotId → condiciones
  final Map<int, CondicionesClimaticasModel> _cache = {};

  Future<CondicionesClimaticasModel?> obtenerCondiciones({
    required int spotId,
    required double latitud,
    required double longitud,
    bool forzarActualizacion = false,
  }) async {
    // Retornar cache si está vigente
    if (!forzarActualizacion && _cache.containsKey(spotId)) {
      final cached = _cache[spotId]!;
      if (!cached.cacheExpirada) return cached;
    }

    try {
      // Llamada paralela: olas (Marine API) + viento (Forecast API)
      final results = await Future.wait([
        _fetchOlas(latitud, longitud),
        _fetchViento(latitud, longitud),
      ]);

      final olas = results[0] as Map<String, dynamic>;
      final viento = results[1] as Map<String, dynamic>;

      final condiciones = _parsear(olas, viento);
      _cache[spotId] = condiciones;
      return condiciones;
    } catch (e) {
      // Sin conexión: devolver cache vencido si existe
      return _cache[spotId];
    }
  }

  Future<Map<String, dynamic>> _fetchOlas(double lat, double lon) async {
    final uri = Uri.parse('$_baseUrl?'
        'latitude=$lat&longitude=$lon'
        '&hourly=wave_height,wave_direction,wave_period'
        '&forecast_days=1&timezone=auto');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchViento(double lat, double lon) async {
    final uri = Uri.parse('$_windUrl?'
        'latitude=$lat&longitude=$lon'
        '&hourly=windspeed_10m,windgusts_10m,winddirection_10m'
        '&forecast_days=1&timezone=auto&windspeed_unit=kn');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  CondicionesClimaticasModel _parsear(
    Map<String, dynamic> olas,
    Map<String, dynamic> viento,
  ) {
    // Tomar el valor de la hora actual
    final now = DateTime.now();
    final horaIdx = now.hour;

    final olasH = olas['hourly'];
    final vientoH = viento['hourly'];

    final waveH   = _safeDouble(olasH?['wave_height'],   horaIdx);
    final windKts = _safeDouble(vientoH?['windspeed_10m'],   horaIdx);
    final gustKts = _safeDouble(vientoH?['windgusts_10m'],   horaIdx);
    final windDir = _safeDouble(vientoH?['winddirection_10m'], horaIdx);

    return CondicionesClimaticasModel(
      vientoKts: windKts,
      rafagasKts: gustKts,
      olasMetros: waveH,
      dirVientoGrados: windDir,
      esOffshore: _esOffshore(windDir),
      esCrossShore: _esCrossShore(windDir),
      actualizadoEn: now,
    );
  }

  double _safeDouble(dynamic list, int idx) {
    if (list == null) return 0.0;
    if (list is List && idx < list.length) {
      return (list[idx] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  // Simplificado: refinamiento real requiere orientación de la costa del spot
  bool _esOffshore(double dir) => dir >= 315 || dir <= 45;
  bool _esCrossShore(double dir) =>
      (dir > 45 && dir < 135) || (dir > 225 && dir < 315);

  void limpiarCache() => _cache.clear();
}
