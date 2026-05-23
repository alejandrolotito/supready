import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_events.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/clima_service.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../widgets/spot_card/spot_card.dart';

class SpotsScreen extends StatefulWidget {
  const SpotsScreen({super.key});
  @override
  State<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends State<SpotsScreen> {
  bool _vistaLista = true, _cargando = true;
  List<SpotModel> _spots = [];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final spotsDB = await SupDatabase.instance.getSpots();
    final spotsConClima = await Future.wait<SpotModel>(spotsDB.map((s) async {
      final c = await ClimaService.instance.obtenerCondiciones(
          spotId: s.spotId!, latitud: s.latitud, longitud: s.longitud);
      return s.copyWith(condiciones: c);
    }));
    if (mounted) setState(() { _spots = spotsConClima; _cargando = false; });
  }

  void _agregarSpot() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: SupColors.backgroundDeep,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AgregarSpotConMapa(onGuardar: (spot) async {
        final id = await SupDatabase.instance.insertarSpot(spot);
        final c = await ClimaService.instance.obtenerCondiciones(
            spotId: id, latitud: spot.latitud, longitud: spot.longitud);
        final nuevo = SpotModel(spotId: id, nombre: spot.nombre, latitud: spot.latitud,
            longitud: spot.longitud, descripcion: spot.descripcion).copyWith(condiciones: c);
        if (mounted) setState(() => _spots = [..._spots, nuevo]);
      }),
    );
  }

  Future<void> _setFavorito(SpotModel spot) async {
    await SupDatabase.instance.setFavorito(spot.spotId!);
    if (mounted) setState(() {
      _spots = _spots.map((s) => s.copyWith(esFavorito: s.spotId == spot.spotId)).toList();
    });
    // Notificar al Home para que se actualice
    AppEvents.instance.notificarFavoritoChanged(spot.spotId!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${spot.nombre} es tu spot favorito ⭐'),
      backgroundColor: SupColors.semaforoVerde));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SupColors.backgroundDeep,
    appBar: AppBar(
      title: const Text('Spots'),
      actions: [
        IconButton(icon: Icon(_vistaLista ? Icons.map_outlined : Icons.list, color: SupColors.cyanNeon),
            onPressed: () => setState(() => _vistaLista = !_vistaLista)),
        IconButton(icon: const Icon(Icons.refresh, color: SupColors.cyanNeon), onPressed: () {
          ClimaService.instance.limpiarCache(); _cargar();
        }),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      backgroundColor: SupColors.cyanNeon, foregroundColor: SupColors.backgroundDeep,
      onPressed: _agregarSpot, child: const Icon(Icons.add),
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon))
        : _vistaLista ? _lista() : _mapa(),
  );

  Widget _lista() => RefreshIndicator(
    color: SupColors.cyanNeon, backgroundColor: SupColors.surface, onRefresh: _cargar,
    child: ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 88),
      itemCount: _spots.length,
      itemBuilder: (_, i) => SpotCard(spot: _spots[i], onTap: () {},
          onFavorito: () => _setFavorito(_spots[i])),
    ),
  );

  Widget _mapa() => FlutterMap(
    options: const MapOptions(initialCenter: LatLng(-38.0, -57.5), initialZoom: 5),
    children: [
      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.supready.app'),
      MarkerLayer(markers: _spots.map((s) {
        final color = _color(s.indiceViabilidad);
        return Marker(
          point: LatLng(s.latitud, s.longitud), width: 44, height: 44,
          child: GestureDetector(
            onTap: () => showModalBottomSheet(context: context,
              backgroundColor: SupColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => Padding(padding: const EdgeInsets.all(20),
                  child: SpotCard(spot: s, onTap: null, onFavorito: () => _setFavorito(s)))),
            child: Stack(alignment: Alignment.topRight, children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: color,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]),
                child: const Icon(Icons.surfing, color: Colors.white, size: 20)),
              if (s.esFavorito)
                Container(width: 14, height: 14,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amber),
                    child: const Icon(Icons.star, size: 9, color: Colors.white)),
            ]),
          ),
        );
      }).toList()),
    ],
  );

  Color _color(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde: return SupColors.semaforoVerde;
      case SupReadyIndex.amarillo: return SupColors.semaforoAmarillo;
      case SupReadyIndex.rojo: return SupColors.semaforoRojo;
      case SupReadyIndex.sinDatos: return SupColors.textSecondary;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Agregar Spot con tap en mapa interactivo
// ─────────────────────────────────────────────────────────────
class _AgregarSpotConMapa extends StatefulWidget {
  final Function(SpotModel) onGuardar;
  const _AgregarSpotConMapa({required this.onGuardar});
  @override
  State<_AgregarSpotConMapa> createState() => _AgregarSpotConMapaState();
}

class _AgregarSpotConMapaState extends State<_AgregarSpotConMapa> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  LatLng? _pinPos;
  bool _paso = false; // false=mapa, true=formulario

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.97, minChildSize: 0.6, expand: false,
      builder: (_, scroll) => Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: SupColors.divider, borderRadius: BorderRadius.circular(2)))),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            if (_paso)
              IconButton(icon: const Icon(Icons.arrow_back, color: SupColors.cyanNeon),
                  onPressed: () => setState(() => _paso = false))
            else
              const SizedBox(width: 40),
            Expanded(child: Text(
              _paso ? 'Datos del spot' : 'Elegí la ubicación',
              style: SupTextStyles.heading2, textAlign: TextAlign.center)),
            const SizedBox(width: 40),
          ]),
        ),
        const Divider(color: SupColors.divider, height: 1),

        if (!_paso) ...[
          // ── PASO 1: Mapa interactivo ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              const Icon(Icons.touch_app, color: SupColors.cyanNeon, size: 18),
              const SizedBox(width: 6),
              const Expanded(child: Text('Tocá el mapa para marcar el spot',
                  style: SupTextStyles.body)),
              if (_pinPos != null)
                Text('${_pinPos!.latitude.toStringAsFixed(4)}, ${_pinPos!.longitude.toStringAsFixed(4)}',
                    style: SupTextStyles.label.copyWith(fontSize: 10)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: const LatLng(-38.0, -57.5),
                    initialZoom: 5,
                    onTap: (_, latlng) => setState(() => _pinPos = latlng),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.supready.app'),
                    if (_pinPos != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _pinPos!, width: 40, height: 40,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 28, height: 28,
                                decoration: BoxDecoration(shape: BoxShape.circle,
                                    color: SupColors.cyanNeon,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [BoxShadow(color: SupColors.cyanNeon.withOpacity(0.5), blurRadius: 8)]),
                                child: const Icon(Icons.surfing, color: SupColors.backgroundDeep, size: 16)),
                            Container(width: 2, height: 10, color: SupColors.cyanNeon),
                          ]),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _pinPos == null ? null : () => setState(() => _paso = true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: _pinPos == null ? SupColors.surface : SupColors.cyanNeon,
                foregroundColor: _pinPos == null ? SupColors.textSecondary : SupColors.backgroundDeep,
              ),
              child: Text(_pinPos == null ? 'MARCÁ UN PUNTO EN EL MAPA' : 'CONTINUAR →'),
            ),
          ),
        ] else ...[
          // ── PASO 2: Formulario ──
          Expanded(
            child: ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
              // Mini mapa confirmación
              Container(
                height: 160,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SupColors.divider)),
                clipBehavior: Clip.hardEdge,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _pinPos!,
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.supready.app'),
                    MarkerLayer(markers: [
                      Marker(point: _pinPos!, width: 28, height: 28,
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, color: SupColors.cyanNeon,
                                border: Border.all(color: Colors.white, width: 2.5)),
                            child: const Icon(Icons.surfing, color: SupColors.backgroundDeep, size: 14))),
                    ]),
                  ],
                ),
              ),
              TextField(
                controller: _nombreCtrl,
                autofocus: true,
                style: const TextStyle(color: SupColors.textPrimary),
                decoration: _deco('Nombre del spot *'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(color: SupColors.textPrimary),
                decoration: _deco('Descripción (ej: condiciones habituales)'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final nombre = _nombreCtrl.text.trim();
                  if (nombre.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ingresá el nombre del spot'),
                      backgroundColor: SupColors.surface));
                    return;
                  }
                  widget.onGuardar(SpotModel(
                    nombre: nombre, latitud: _pinPos!.latitude,
                    longitud: _pinPos!.longitude, descripcion: _descCtrl.text.trim()));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                child: const Text('GUARDAR SPOT'),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: SupColors.textSecondary),
    filled: true, fillColor: SupColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SupColors.divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SupColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SupColors.cyanNeon, width: 1.5)),
  );
}
