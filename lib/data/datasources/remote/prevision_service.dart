import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prevision_model.dart';

// ============================================================
// SUPReady - Servicio de Previsión Horaria
// Open-Meteo + Marine API — gratuito, sin key
// Datos: viento, ráfagas, olas, lluvia, tormenta, amanecer/anochecer
// ============================================================

class PrevisionService {
  static final PrevisionService instance = PrevisionService._();
  PrevisionService._();

  // Cache por spot: lista de horas
  final Map<String, List<PrevisionHoraria>> _cacheHorario = {};
  final Map<String, DatosSolares> _cacheSolar = {};
  final Map<String, DateTime> _cacheTs = {};

  Future<List<PrevisionHoraria>> obtenerPrevisionHoraria({
    required double latitud,
    required double longitud,
  }) async {
    final key = '${latitud.toStringAsFixed(3)}_${longitud.toStringAsFixed(3)}';
    final ahora = DateTime.now();

    // Cache de 30 min
    if (_cacheHorario.containsKey(key) && _cacheTs.containsKey(key)) {
      if (ahora.difference(_cacheTs[key]!).inMinutes < 30) {
        return _cacheHorario[key]!;
      }
    }

    try {
      final results = await Future.wait([
        _fetchForecast(latitud, longitud),
        _fetchMarine(latitud, longitud),
      ]);

      final forecast = results[0];
      final marine   = results[1];
      final horas = _parsear(forecast, marine);

      _cacheHorario[key] = horas;
      _cacheTs[key] = ahora;
      return horas;
    } catch (_) {
      return _cacheHorario[key] ?? [];
    }
  }

  Future<DatosSolares?> obtenerDatosSolares({
    required double latitud,
    required double longitud,
  }) async {
    final key = '${latitud.toStringAsFixed(3)}_${longitud.toStringAsFixed(3)}';
    if (_cacheSolar.containsKey(key)) return _cacheSolar[key];

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitud&longitude=$longitud'
        '&daily=sunrise,sunset&forecast_days=1&timezone=auto',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final sunriseList = daily['sunrise'] as List?;
      final sunsetList  = daily['sunset']  as List?;
      if (sunriseList == null || sunsetList == null || sunriseList.isEmpty) return null;

      final solar = DatosSolares(
        amanecer:  DateTime.parse(sunriseList[0] as String),
        anochecer: DateTime.parse(sunsetList[0]  as String),
      );
      _cacheSolar[key] = solar;
      return solar;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _fetchForecast(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?'
      'latitude=$lat&longitude=$lon'
      '&hourly=windspeed_10m,windgusts_10m,winddirection_10m,'
      'precipitation_probability,precipitation,thunderstorm_probability'
      '&forecast_days=2&timezone=auto&windspeed_unit=kn',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchMarine(double lat, double lon) async {
    final uri = Uri.parse(
      'https://marine-api.open-meteo.com/v1/marine?'
      'latitude=$lat&longitude=$lon'
      '&hourly=wave_height,wave_direction,sea_surface_temperature'
      '&forecast_days=2&timezone=auto',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  List<PrevisionHoraria> _parsear(
    Map<String, dynamic> forecast,
    Map<String, dynamic> marine,
  ) {
    final fH = forecast['hourly'] as Map<String, dynamic>?;
    final mH = marine['hourly']   as Map<String, dynamic>?;
    if (fH == null) return [];

    final times       = (fH['time']                     as List?)?.cast<String>() ?? [];
    final viento      = (fH['windspeed_10m']             as List?)?.cast<num>()   ?? [];
    final rafagas     = (fH['windgusts_10m']             as List?)?.cast<num>()   ?? [];
    final dirViento   = (fH['winddirection_10m']         as List?)?.cast<num>()   ?? [];
    final probLluvia  = (fH['precipitation_probability'] as List?)?.cast<num>()   ?? [];
    final precip      = (fH['precipitation']             as List?)?.cast<num>()   ?? [];
    final tormenta    = (fH['thunderstorm_probability']  as List?)?.cast<num?>()  ?? [];
    final olas        = (mH?['wave_height']              as List?)?.cast<num?>()  ?? [];
    final sst         = (mH?['sea_surface_temperature']  as List?)?.cast<num?>()  ?? [];

    final now = DateTime.now();
    final horas = <PrevisionHoraria>[];

    for (int i = 0; i < times.length && i < 48; i++) {
      final hora = DateTime.tryParse(times[i]);
      if (hora == null) continue;
      // Solo mostrar desde hora actual hasta 48h
      if (hora.isBefore(now.subtract(const Duration(hours: 1)))) continue;

      horas.add(PrevisionHoraria(
        hora: hora,
        vientoKts: i < viento.length ? viento[i].toDouble() : 0,
        rachasKts: i < rafagas.length ? rafagas[i].toDouble() : 0,
        olasMetros: i < olas.length ? (olas[i]?.toDouble() ?? 0) : 0,
        dirVientoGrados: i < dirViento.length ? dirViento[i].toDouble() : 0,
        probabilidadLluvia: i < probLluvia.length ? probLluvia[i].toDouble() : 0,
        precipitacionMm: i < precip.length ? precip[i].toDouble() : 0,
        tormentaElectrica: i < tormenta.length ? (tormenta[i]?.toDouble() ?? 0) > 20 : false,
        tempAguaC: i < sst.length ? sst[i]?.toDouble() : null,
      ));
    }
    return horas;
  }

  void limpiarCache() {
    _cacheHorario.clear();
    _cacheTs.clear();
    _cacheSolar.clear();
  }
}
