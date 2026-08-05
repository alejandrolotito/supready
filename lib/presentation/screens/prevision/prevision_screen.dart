import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/prevision_service.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/models/prevision_model.dart';

// ============================================================
// SUPReady - Pantalla de Previsión Horaria
// 48h · viento/ráfagas en nudos · lluvia · tormenta · sol
// ============================================================

class PrevisionScreen extends StatefulWidget {
  const PrevisionScreen({super.key});
  @override
  State<PrevisionScreen> createState() => _PrevisionScreenState();
}

class _PrevisionScreenState extends State<PrevisionScreen> {
  List<PrevisionHoraria> _horas = [];
  DatosSolares? _solar;
  bool _cargando = true;
  String _spotNombre = 'Spot favorito';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final spot = await SupDatabase.instance.getSpotFavorito();
    final lat = spot?.latitud ?? -38.0055;
    final lon = spot?.longitud ?? -57.5426;
    if (spot != null) _spotNombre = spot.nombre;

    final results = await Future.wait([
      PrevisionService.instance.obtenerPrevisionHoraria(latitud: lat, longitud: lon),
      PrevisionService.instance.obtenerDatosSolares(latitud: lat, longitud: lon),
    ]);

    if (mounted) setState(() {
      _horas  = results[0] as List<PrevisionHoraria>;
      _solar  = results[1] as DatosSolares?;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SupColors.backgroundDeep,
    appBar: AppBar(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Previsión 48h'),
        Text(_spotNombre, style: SupTextStyles.body.copyWith(fontSize: 12)),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: SupColors.cyanNeon),
          onPressed: () { PrevisionService.instance.limpiarCache(); _cargar(); }),
      ],
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon))
        : _horas.isEmpty
            ? _buildSinDatos()
            : RefreshIndicator(
                color: SupColors.cyanNeon, backgroundColor: SupColors.surface,
                onRefresh: _cargar,
                child: ListView(children: [
                  if (_solar != null) _buildSolar(),
                  _buildAlertasTormenta(),
                  _buildAlertaOffshore(),
                  _buildTablaHoraria(),
                  const SizedBox(height: 24),
                ]),
              ),
  );

  Widget _buildSinDatos() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off, color: SupColors.textSecondary, size: 64),
    const SizedBox(height: 16),
    const Text('Sin datos de previsión', style: SupTextStyles.heading2),
    const SizedBox(height: 8),
    const Text('Verificá tu conexión a internet', style: SupTextStyles.body),
  ]));

  Widget _buildSolar() {
    final s = _solar!;
    final fmt = (DateTime dt) =>
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    final luzDia = s.anochecer.difference(s.amanecer);
    final hs = luzDia.inHours;
    final ms = luzDia.inMinutes % 60;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SupColors.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SupColors.divider),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _solarItem(Icons.wb_sunny_outlined, 'AMANECER', fmt(s.amanecer), const Color(0xFFFFA726)),
        Container(width: 1, height: 44, color: SupColors.divider),
        _solarItem(Icons.nightlight_outlined, 'ANOCHECER', fmt(s.anochecer), const Color(0xFF7986CB)),
        Container(width: 1, height: 44, color: SupColors.divider),
        _solarItem(Icons.light_mode_outlined, 'LUZ DEL DÍA', '${hs}h ${ms}m', SupColors.cyanNeon),
      ]),
    );
  }

  Widget _solarItem(IconData icon, String label, String valor, Color color) =>
      Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: SupTextStyles.label.copyWith(fontSize: 9, color: color)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(
            color: Colors.white, fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w700, fontSize: 15)),
      ]);

  Widget _buildAlertasTormenta() {
    final tormentas = _horas.where((h) => h.tormentaElectrica).toList();
    final lluvia    = _horas.where((h) => h.probabilidadLluvia > 60).toList();

    if (tormentas.isEmpty && lluvia.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SupColors.semaforoRojo.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SupColors.semaforoRojo.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bolt, color: SupColors.semaforoRojo, size: 18),
          SizedBox(width: 6),
          Text('ALERTAS METEOROLÓGICAS', style: TextStyle(
              color: SupColors.semaforoRojo, fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 8),
        if (tormentas.isNotEmpty)
          Text(
            '⚡ Tormenta eléctrica posible: ${_rangoHoras(tormentas)}',
            style: const TextStyle(color: Colors.white, fontFamily: 'SpaceGrotesk', fontSize: 13)),
        if (lluvia.isNotEmpty)
          Text(
            '🌧 Lluvia probable: ${_rangoHoras(lluvia)}',
            style: TextStyle(color: SupColors.textSecondary.withRed(200), fontFamily: 'SpaceGrotesk', fontSize: 13)),
      ]),
    );
  }

  String _rangoHoras(List<PrevisionHoraria> horas) {
    if (horas.isEmpty) return '';
    final fmt = (DateTime dt) => '${dt.hour.toString().padLeft(2,'0')}h';
    if (horas.length == 1) return fmt(horas.first.hora);
    return '${fmt(horas.first.hora)} – ${fmt(horas.last.hora)}';
  }


  Widget _buildAlertaOffshore() {
    // Viento de tierra (S, SO, O) con > 12 kts → alerta crítica
    final offshoreHoras = _horas.where((h) {
      final dir = h.dirTexto;
      return h.vientoKts > 12 &&
          (dir == 'S' || dir == 'SO' || dir == 'O' || dir == 'NO');
    }).toList();
    if (offshoreHoras.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7C1D1D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SupColors.semaforoRojo, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('⚠️ VIENTO DE TIERRA — RIESGO CRÍTICO',
              style: TextStyle(color: Colors.white, fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Viento offshore detectado. Esta condición puede alejarte '
          'de la costa sin posibilidad de regreso. '
          'NO se recomienda salir al agua.',
          style: TextStyle(color: Colors.white70, fontFamily: 'SpaceGrotesk',
              fontSize: 12, height: 1.5)),
        const SizedBox(height: 6),
        Text(
          'Rango: ${_rangoHoras(offshoreHoras)} · '
          'Máx ${offshoreHoras.map((h) => h.vientoKts).reduce((a,b) => a>b?a:b).toStringAsFixed(0)} kts',
          style: const TextStyle(color: Colors.white,
              fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _buildTablaHoraria() {
    // Agrupar por día
    final Map<String, List<PrevisionHoraria>> porDia = {};
    for (final h in _horas) {
      final diasSemana = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
      final meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      final hoy = DateTime.now();
      String key;
      if (h.hora.day == hoy.day) key = 'Hoy';
      else if (h.hora.day == hoy.day + 1) key = 'Mañana';
      else key = '${diasSemana[h.hora.weekday-1]} ${h.hora.day} ${meses[h.hora.month-1]}';
      porDia.putIfAbsent(key, () => []).add(h);
    }

    return Column(
      children: porDia.entries.map((e) => _buildDia(e.key, e.value)).toList());
  }

  Widget _buildDia(String titulo, List<PrevisionHoraria> horas) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(titulo, style: SupTextStyles.heading2.copyWith(fontSize: 16)),
      ),
      // Cabecera tabla
      Container(
        color: SupColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _thCell('HORA', 48),
          _thCell('VIENTO', 68),
          _thCell('RÁFAGAS', 72),
          _thCell('OLAS', 56),
          _thCell('LLUVIA', 56),
          _thCell('ESTADO', 60),
        ]),
      ),
      const Divider(height: 1, color: SupColors.divider),
      // Filas
      ...horas.map(_buildFila),
    ]);
  }

  Widget _thCell(String label, double w) => SizedBox(
    width: w,
    child: Text(label, style: const TextStyle(
        color: SupColors.textSecondary, fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w600, fontSize: 9, letterSpacing: 0.6),
        textAlign: TextAlign.center),
  );

  Widget _buildFila(PrevisionHoraria h) {
    final bgColor = h.nivelRiesgo == 2
        ? SupColors.semaforoRojo.withOpacity(0.06)
        : h.nivelRiesgo == 1
            ? SupColors.semaforoAmarillo.withOpacity(0.04)
            : Colors.transparent;

    // Marcar amanecer/anochecer
    bool esAmanecer = false, esAnochecer = false;
    if (_solar != null) {
      esAmanecer  = h.hora.hour == _solar!.amanecer.hour;
      esAnochecer = h.hora.hour == _solar!.anochecer.hour;
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        // Hora
        SizedBox(width: 48, child: Column(children: [
          Text('${h.hora.hour.toString().padLeft(2,'0')}:00',
              style: const TextStyle(color: Colors.white, fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w600, fontSize: 14)),
          if (esAmanecer)
            const Text('🌅', style: TextStyle(fontSize: 10))
          else if (esAnochecer)
            const Text('🌇', style: TextStyle(fontSize: 10)),
        ])),

        // Viento
        SizedBox(width: 68, child: _windCell(h.vientoKts, false)),

        // Ráfagas
        SizedBox(width: 72, child: _windCell(h.rachasKts, true)),

        // Olas
        SizedBox(width: 56, child: Text(
          '${h.olasMetros.toStringAsFixed(1)} m',
          style: TextStyle(
              color: h.olasMetros >= 1.0 ? SupColors.semaforoRojo
                  : h.olasMetros >= 0.5 ? SupColors.semaforoAmarillo
                  : SupColors.semaforoVerde,
              fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w600, fontSize: 13),
          textAlign: TextAlign.center)),

        // Lluvia
        SizedBox(width: 56, child: Column(children: [
          Text('${h.probabilidadLluvia.toStringAsFixed(0)}%',
              style: TextStyle(
                  color: h.probabilidadLluvia > 60 ? SupColors.semaforoAmarillo
                      : SupColors.textSecondary,
                  fontFamily: 'JetBrainsMono', fontSize: 13),
              textAlign: TextAlign.center),
          if (h.precipitacionMm > 0)
            Text('${h.precipitacionMm.toStringAsFixed(1)} mm',
                style: const TextStyle(color: SupColors.textSecondary, fontSize: 9),
                textAlign: TextAlign.center),
        ])),

        // Estado / ícono
        SizedBox(width: 60, child: Center(child: _estadoIcon(h))),
      ]),
    );
  }

  Widget _windCell(double kts, bool esRafaga) {
    Color color;
    if (kts > 18) color = SupColors.semaforoRojo;
    else if (kts > 10) color = SupColors.semaforoAmarillo;
    else color = SupColors.semaforoVerde;

    return Column(children: [
      Text('${kts.toStringAsFixed(0)} kt',
          style: TextStyle(color: color, fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w700, fontSize: 14),
          textAlign: TextAlign.center),
      if (esRafaga)
        Text('máx', style: TextStyle(color: color.withOpacity(0.7),
            fontSize: 9, fontFamily: 'SpaceGrotesk')),
    ]);
  }

  Widget _estadoIcon(PrevisionHoraria h) {
    if (h.tormentaElectrica) {
      return const Column(children: [
        Icon(Icons.bolt, color: SupColors.semaforoRojo, size: 20),
        Text('⚡ tormenta', style: TextStyle(
            color: SupColors.semaforoRojo, fontSize: 8, fontFamily: 'SpaceGrotesk')),
      ]);
    }
    if (h.probabilidadLluvia > 60) {
      return Column(children: [
        Icon(Icons.water_drop, color: SupColors.semaforoAmarillo.withBlue(200), size: 18),
        Text('lluvia', style: TextStyle(
            color: SupColors.semaforoAmarillo.withBlue(200), fontSize: 8, fontFamily: 'SpaceGrotesk')),
      ]);
    }
    switch (h.nivelRiesgo) {
      case 0: return const Icon(Icons.check_circle, color: SupColors.semaforoVerde, size: 18);
      case 1: return const Icon(Icons.warning_amber, color: SupColors.semaforoAmarillo, size: 18);
      case 2: return const Icon(Icons.cancel, color: SupColors.semaforoRojo, size: 18);
      default: return const SizedBox.shrink();
    }
  }
}
