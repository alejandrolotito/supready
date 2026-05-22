import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';

// ============================================================
// SUPReady v3 - Historial de rutas
// - Lista de todas las remadas
// - Detalle con mapa y tramos coloreados por velocidad
// ============================================================

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<RutaTrazadaModel> _rutas = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargarRutas(); }

  Future<void> _cargarRutas() async {
    setState(() => _cargando = true);
    final usuario = AuthService.instance.usuarioActual;
    if (usuario?.usuarioId != null) {
      final rutas = await SupDatabase.instance.getRutasPorUsuario(usuario!.usuarioId!);
      if (mounted) setState(() { _rutas = rutas; _cargando = false; });
    } else {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(title: const Text('Historial')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon))
          : _rutas.isEmpty
              ? _buildVacio()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _rutas.length,
                  itemBuilder: (_, i) => _RutaHistorialCard(
                    ruta: _rutas[i],
                    onTap: () => _verDetalle(_rutas[i]),
                  ),
                ),
    );
  }

  Widget _buildVacio() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.history, color: SupColors.textSecondary, size: 64),
    const SizedBox(height: 16),
    const Text('Sin remadas todavía', style: SupTextStyles.heading2),
    const SizedBox(height: 8),
    const Text('Tus rutas aparecerán acá\ndespués de cada remada',
        style: SupTextStyles.body, textAlign: TextAlign.center),
  ]));

  void _verDetalle(RutaTrazadaModel ruta) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _DetalleRutaScreen(ruta: ruta)));
  }
}

class _RutaHistorialCard extends StatelessWidget {
  final RutaTrazadaModel ruta;
  final VoidCallback onTap;
  const _RutaHistorialCard({required this.ruta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dias = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = ruta.iniciadaEn;
    final fecha = '${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month-1]} ${dt.year}';
    final hora = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SupColors.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SupColors.divider),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: SupColors.cyanNeonDim, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.route, color: SupColors.cyanNeon, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fecha, style: SupTextStyles.body.copyWith(fontSize: 12)),
            const SizedBox(height: 2),
            Text('${ruta.distanciaKm.toStringAsFixed(2)} km · ${ruta.duracionMinutos} min',
                style: const TextStyle(color: SupColors.textPrimary, fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 2),
            Text('Vel. media: ${ruta.velocidadMedia.toStringAsFixed(1)} km/h  ·  $hora',
                style: SupTextStyles.body.copyWith(fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: SupColors.textSecondary),
        ]),
      ),
    );
  }
}

// ----------------------------------------------------------
// Detalle de ruta con mapa y tramos coloreados
// ----------------------------------------------------------
class _DetalleRutaScreen extends StatefulWidget {
  final RutaTrazadaModel ruta;
  const _DetalleRutaScreen({required this.ruta});
  @override
  State<_DetalleRutaScreen> createState() => _DetalleRutaScreenState();
}

class _DetalleRutaScreenState extends State<_DetalleRutaScreen> {
  List<CoordenadasRutaModel> _coords = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargarCoords(); }

  Future<void> _cargarCoords() async {
    if (widget.ruta.rutaId != null) {
      final coords = await SupDatabase.instance.getCoordenadas(widget.ruta.rutaId!);
      if (mounted) setState(() { _coords = coords; _cargando = false; });
    } else {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Polyline> _buildPolylines() {
    if (_coords.length < 2) return [];
    final points = _coords.map((c) => LatLng(c.latitud, c.longitud)).toList();
    final polylines = <Polyline>[];
    // Dividir en 3 tramos: lento, medio, rápido
    final tramo = points.length ~/ 3;
    final colores = [SupColors.semaforoVerde, SupColors.semaforoAmarillo, SupColors.semaforoRojo];
    for (int i = 0; i < 3; i++) {
      final inicio = i * tramo;
      final fin = i == 2 ? points.length : (i + 1) * tramo + 1;
      if (inicio < points.length) {
        polylines.add(Polyline(points: points.sublist(inicio, fin.clamp(0, points.length)),
            color: colores[i], strokeWidth: 5));
      }
    }
    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    final ruta = widget.ruta;
    final center = _coords.isNotEmpty
        ? LatLng(_coords[_coords.length ~/ 2].latitud, _coords[_coords.length ~/ 2].longitud)
        : const LatLng(-38.0, -57.5);

    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(title: const Text('Detalle de remada')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon))
          : Column(children: [
              // Mapa con tramos
              Expanded(
                flex: 3,
                child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 14),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.supready.app'),
                    PolylineLayer(polylines: _buildPolylines()),
                    if (_coords.isNotEmpty) ...[
                      MarkerLayer(markers: [
                        Marker(point: LatLng(_coords.first.latitud, _coords.first.longitud),
                            width: 28, height: 28,
                            child: Container(decoration: const BoxDecoration(shape: BoxShape.circle,
                                color: SupColors.semaforoVerde),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 16))),
                        Marker(point: LatLng(_coords.last.latitud, _coords.last.longitud),
                            width: 28, height: 28,
                            child: Container(decoration: const BoxDecoration(shape: BoxShape.circle,
                                color: SupColors.semaforoRojo),
                                child: const Icon(Icons.stop, color: Colors.white, size: 16))),
                      ]),
                    ],
                  ],
                ),
              ),
              // Leyenda velocidad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: SupColors.surface,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _leyendaItem(SupColors.semaforoVerde, 'Lento'),
                  const SizedBox(width: 20),
                  _leyendaItem(SupColors.semaforoAmarillo, 'Medio'),
                  const SizedBox(width: 20),
                  _leyendaItem(SupColors.semaforoRojo, 'Rápido'),
                ]),
              ),
              // Stats
              Expanded(
                flex: 2,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  _statRow('Distancia', '${ruta.distanciaKm.toStringAsFixed(2)} km'),
                  _statRow('Duración', '${ruta.duracionMinutos} min'),
                  _statRow('Velocidad media', '${ruta.velocidadMedia.toStringAsFixed(1)} km/h'),
                  _statRow('Velocidad máxima', '${ruta.velocidadMaxima.toStringAsFixed(1)} km/h'),
                  _statRow('Puntos GPS', '${_coords.length}'),
                ]),
              ),
            ]),
    );
  }

  Widget _leyendaItem(Color color, String label) => Row(children: [
    Container(width: 20, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 6),
    Text(label, style: SupTextStyles.body.copyWith(fontSize: 12)),
  ]);

  Widget _statRow(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: SupTextStyles.body),
      Text(valor, style: const TextStyle(color: SupColors.textPrimary, fontFamily: 'JetBrainsMono',
          fontWeight: FontWeight.w700, fontSize: 15)),
    ]),
  );
}
