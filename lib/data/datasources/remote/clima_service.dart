import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/models.dart';

// ============================================================
// SUPReady v3 - Servicio de Clima Marítimo
// Open-Meteo Marine API + Forecast API — gratuitas, sin API key
// Datos: viento (kts), ráfagas, olas, dirección, temp agua
// Refresco: cache 30 min por spot
// ============================================================

class ClimaService {
  static final ClimaService instance = ClimaService._();
  ClimaService._();

  static const _marineUrl = 'https://marine-api.open-meteo.com/v1/marine';
  static const _forecastUrl = 'https://api.open-meteo.com/v1/forecast';

  final Map<int, CondicionesClimaticasModel> _cache = {};

  Future<CondicionesClimaticasModel?> obtenerCondiciones({
    required int spotId,
    required double latitud,
    required double longitud,
    bool forzar = false,
  }) async {
    if (!forzar && _cache.containsKey(spotId) && !_cache[spotId]!.cacheExpirada) {
      return _cache[spotId];
    }
    try {
      final results = await Future.wait([
        _fetchMarine(latitud, longitud),
        _fetchViento(latitud, longitud),
      ]);
      final condiciones = _parsear(results[0], results[1]);
      _cache[spotId] = condiciones;
      return condiciones;
    } catch (_) {
      return _cache[spotId]; // devuelve cache vencida si hay
    }
  }

  Future<Map<String, dynamic>> _fetchMarine(double lat, double lon) async {
    final uri = Uri.parse(
      '$_marineUrl?latitude=$lat&longitude=$lon'
      '&hourly=wave_height,wave_direction,wave_period,sea_surface_temperature'
      '&current=wave_height,wave_direction'
      '&forecast_days=1&timezone=auto',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) throw Exception('Marine API ${resp.statusCode}');
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchViento(double lat, double lon) async {
    final uri = Uri.parse(
      '$_forecastUrl?latitude=$lat&longitude=$lon'
      '&hourly=windspeed_10m,windgusts_10m,winddirection_10m'
      '&current=windspeed_10m,windgusts_10m,winddirection_10m'
      '&forecast_days=1&timezone=auto&windspeed_unit=kn',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) throw Exception('Forecast API ${resp.statusCode}');
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  CondicionesClimaticasModel _parsear(
    Map<String, dynamic> marine,
    Map<String, dynamic> viento,
  ) {
    // Priorizar datos "current" (tiempo real) sobre hourly
    final marCurrent = marine['current'] as Map<String, dynamic>?;
    final vCurrent   = viento['current']  as Map<String, dynamic>?;
    final mHourly    = marine['hourly']   as Map<String, dynamic>?;
    final vHourly    = viento['hourly']   as Map<String, dynamic>?;

    final hora = DateTime.now().hour;

    final waveH   = _num(marCurrent?['wave_height'])  ?? _numAt(mHourly?['wave_height'], hora);
    final windKts = _num(vCurrent?['windspeed_10m'])   ?? _numAt(vHourly?['windspeed_10m'], hora);
    final gustKts = _num(vCurrent?['windgusts_10m'])   ?? _numAt(vHourly?['windgusts_10m'], hora);
    final windDir = _num(vCurrent?['winddirection_10m']) ?? _numAt(vHourly?['winddirection_10m'], hora);
    final sst     = _numAt(mHourly?['sea_surface_temperature'], hora); // °C, puede ser null

    return CondicionesClimaticasModel(
      vientoKts: windKts,
      rafagasKts: gustKts,
      olasMetros: waveH,
      dirVientoGrados: windDir,
      esOffshore: _esOffshore(windDir),
      esCrossShore: _esCrossShore(windDir),
      tempAguaC: sst,
      actualizadoEn: DateTime.now(),
    );
  }

  double _num(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
  double _numAt(dynamic list, int idx) {
    if (list == null || list is! List || idx >= list.length) return 0.0;
    return (list[idx] as num?)?.toDouble() ?? 0.0;
  }

  bool _esOffshore(double dir) => dir >= 315 || dir <= 45;
  bool _esCrossShore(double dir) =>
      (dir > 45 && dir < 135) || (dir > 225 && dir < 315);

  void limpiarCache() => _cache.clear();
}
