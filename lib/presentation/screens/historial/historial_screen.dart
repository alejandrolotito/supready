import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../widgets/common/ruta_share_card.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<RutaTrazadaModel> _rutas = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final usuario = AuthService.instance.usuarioActual;
    final rutas = usuario?.usuarioId != null
        ? await SupDatabase.instance.getRutasPorUsuario(usuario!.usuarioId!)
        : await SupDatabase.instance.getAllRutas();
    if (mounted) setState(() { _rutas = rutas; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SupColors.backgroundDeep,
    appBar: AppBar(title: const Text('Historial'), actions: [
      IconButton(icon: const Icon(Icons.refresh, color: SupColors.cyanNeon), onPressed: _cargar),
    ]),
    body: _cargando
        ? const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon))
        : _rutas.isEmpty ? _vacio() : RefreshIndicator(
            color: SupColors.cyanNeon, backgroundColor: SupColors.surface,
            onRefresh: _cargar,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _rutas.length,
              itemBuilder: (_, i) => _RutaCard(
                ruta: _rutas[i],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DetalleRutaScreen(ruta: _rutas[i])))),
            )),
  );

  Widget _vacio() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.history, color: SupColors.textSecondary, size: 64),
    const SizedBox(height: 16),
    const Text('Sin remadas todavía', style: SupTextStyles.heading2),
    const SizedBox(height: 8),
    const Text('Tus rutas aparecerán acá\ndespués de cada remada',
        style: SupTextStyles.body, textAlign: TextAlign.center),
  ]));
}

// ─── Card compacta ────────────────────────────────────────────
class _RutaCard extends StatelessWidget {
  final RutaTrazadaModel ruta;
  final VoidCallback onTap;
  const _RutaCard({required this.ruta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dt = ruta.iniciadaEn;
    final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: SupColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SupColors.divider)),
        child: Row(children: [
          Container(width: 52, height: 52,
              decoration: BoxDecoration(color: SupColors.cyanNeonDim,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.route, color: SupColors.cyanNeon, size: 26)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} ${dt.year}',
                style: SupTextStyles.body.copyWith(fontSize: 12)),
            const SizedBox(height: 2),
            Text('${ruta.distanciaKm.toStringAsFixed(2)} km · ${ruta.duracionMinutos} min',
                style: const TextStyle(color: SupColors.textPrimary,
                    fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 17)),
            Text('${ruta.velocidadMedia.toStringAsFixed(1)} km/h media · '
                '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                style: SupTextStyles.body.copyWith(fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: SupColors.textSecondary),
        ]),
      ),
    );
  }
}

// ─── Detalle con mapa coloreado por velocidad + compartir ─────
class _DetalleRutaScreen extends StatefulWidget {
  final RutaTrazadaModel ruta;
  const _DetalleRutaScreen({required this.ruta});
  @override
  State<_DetalleRutaScreen> createState() => _DetalleRutaScreenState();
}

class _DetalleRutaScreenState extends State<_DetalleRutaScreen> {
  List<CoordenadasRutaModel> _coords = [];
  bool _cargando = true;
  double _velMax = 0, _velMin = double.infinity;
  bool _mostrandoCard = false;
  final _shareKey = GlobalKey();

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    if (widget.ruta.rutaId == null) { setState(() => _cargando = false); return; }
    final coords = await SupDatabase.instance.getCoordenadas(widget.ruta.rutaId!);
    if (mounted) {
      double vMax = 0, vMin = double.infinity;
      for (final c in coords) {
        if (c.velocidadKmh > vMax) vMax = c.velocidadKmh;
        if (c.velocidadKmh < vMin) vMin = c.velocidadKmh;
      }
      setState(() {
        _coords = coords; _cargando = false;
        _velMax = vMax; _velMin = vMin == double.infinity ? 0 : vMin;
      });
    }
  }

  Future<void> _compartir() async {
    setState(() => _mostrandoCard = true);
    await Future.delayed(const Duration(milliseconds: 300));
    await compartirRutaComoImagen(_shareKey, widget.ruta);
    if (mounted) setState(() => _mostrandoCard = false);
  }

  Color _colorVel(double vel) {
    final rango = _velMax - _velMin;
    if (rango < 0.5) return SupColors.cyanNeon;
    final t = ((vel - _velMin) / rango).clamp(0.0, 1.0);
    if (t < 0.5) return Color.lerp(SupColors.semaforoVerde, SupColors.semaforoAmarillo, t * 2)!;
    return Color.lerp(SupColors.semaforoAmarillo, SupColors.semaforoRojo, (t - 0.5) * 2)!;
  }

  List<Polyline> _buildPolylines() {
    if (_coords.length < 2) return [];
    return List.generate(_coords.length - 1, (i) {
      final velMedia = (_coords[i].velocidadKmh + _coords[i+1].velocidadKmh) / 2;
      return Polyline(
        points: [LatLng(_coords[i].latitud, _coords[i].longitud),
                 LatLng(_coords[i+1].latitud, _coords[i+1].longitud)],
        color: _colorVel(velMedia), strokeWidth: 5);
    });
  }

  Marker _marker(CoordenadasRutaModel c, Color color, IconData icon) => Marker(
    point: LatLng(c.latitud, c.longitud), width: 28, height: 28,
    child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 16)));

  @override
  Widget build(BuildContext context) {
    final ruta = widget.ruta;
    final center = _coords.isNotEmpty
        ? LatLng(_coords[_coords.length ~/ 2].latitud, _coords[_coords.length ~/ 2].longitud)
        : const LatLng(-38.0, -57.5);

    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Detalle de remada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SupColors.cyanNeon),
            onPressed: _compartir),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon))
          : Stack(children: [
              Column(children: [
                // Mapa
                Expanded(flex: 3, child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 14),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.supready.app'),
                    if (_coords.length >= 2) PolylineLayer(polylines: _buildPolylines()),
                    if (_coords.isNotEmpty) MarkerLayer(markers: [
                      _marker(_coords.first, SupColors.semaforoVerde, Icons.play_arrow),
                      _marker(_coords.last, SupColors.semaforoRojo, Icons.stop),
                    ]),
                  ],
                )),
                // Leyenda
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: SupColors.surface,
                  child: Row(children: [
                    const Text('Velocidad:', style: SupTextStyles.body),
                    const SizedBox(width: 12),
                    _leyenda(SupColors.semaforoVerde, 'Lenta'),
                    const SizedBox(width: 16),
                    _leyenda(SupColors.semaforoAmarillo, 'Media'),
                    const SizedBox(width: 16),
                    _leyenda(SupColors.semaforoRojo, 'Rápida'),
                    const Spacer(),
                    Text('${_velMin.toStringAsFixed(1)}–${_velMax.toStringAsFixed(1)} km/h',
                        style: SupTextStyles.body.copyWith(fontSize: 11)),
                  ]),
                ),
                // Stats
                Expanded(flex: 2, child: ListView(
                  padding: const EdgeInsets.all(16), children: [
                  _stat('Distancia', '${ruta.distanciaKm.toStringAsFixed(2)} km'),
                  _stat('Duración', '${ruta.duracionMinutos} min'),
                  _stat('Velocidad media', '${ruta.velocidadMedia.toStringAsFixed(1)} km/h'),
                  _stat('Velocidad máxima', '${ruta.velocidadMaxima.toStringAsFixed(1)} km/h'),
                  _stat('Puntos GPS', '${_coords.length}'),
                ])),
              ]),
              // Card invisible para captura
              if (_mostrandoCard)
                Positioned(left: -9999, top: -9999,
                  child: RutaShareCard(repaintKey: _shareKey, ruta: ruta)),
            ]),
    );
  }

  Widget _leyenda(Color color, String label) => Row(children: [
    Container(width: 20, height: 4,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label, style: SupTextStyles.body.copyWith(fontSize: 11)),
  ]);

  Widget _stat(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: SupTextStyles.body),
      Text(valor, style: const TextStyle(color: SupColors.textPrimary,
          fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 15)),
    ]),
  );
}
