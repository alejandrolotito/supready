import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/clima_service.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../widgets/spot_card/spot_card.dart';

// ============================================================
// SUPReady v3 - Spots Screen
// - Datos en tiempo real (Open-Meteo Marine)
// - Agregar nuevo spot desde mapa o coordenadas
// - Vista lista + vista mapa con pins de colores
// ============================================================

class SpotsScreen extends StatefulWidget {
  const SpotsScreen({super.key});
  @override
  State<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends State<SpotsScreen> {
  bool _vistaLista = true;
  bool _cargando = true;
  List<SpotModel> _spots = [];

  static final _spotsIniciales = [
    SpotModel(spotId: 1, nombre: 'Playa Grande MDQ', latitud: -38.0055, longitud: -57.5426, descripcion: 'Mar del Plata'),
    SpotModel(spotId: 2, nombre: 'Punta Mogotes', latitud: -38.0700, longitud: -57.5300, descripcion: 'Mar del Plata Sur'),
    SpotModel(spotId: 3, nombre: 'Río de la Plata - Olivos', latitud: -34.5019, longitud: -58.4988, descripcion: 'Buenos Aires Norte'),
  ];

  @override
  void initState() { super.initState(); _cargarSpots(); }

  Future<void> _cargarSpots() async {
    setState(() => _cargando = true);
    final spotsConClima = await Future.wait(_spotsIniciales.map((spot) async {
      final clima = await ClimaService.instance.obtenerCondiciones(
        spotId: spot.spotId!, latitud: spot.latitud, longitud: spot.longitud);
      return SpotModel(spotId: spot.spotId, nombre: spot.nombre, latitud: spot.latitud,
          longitud: spot.longitud, descripcion: spot.descripcion, condiciones: clima);
    }));
    if (mounted) setState(() { _spots = spotsConClima; _cargando = false; });
  }

  void _agregarSpot() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: SupColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AgregarSpotSheet(onGuardar: (spot) {
        setState(() => _spots = [..._spots, spot]);
        _cargarClimaSpot(spot);
      }),
    );
  }

  Future<void> _cargarClimaSpot(SpotModel spot) async {
    final clima = await ClimaService.instance.obtenerCondiciones(
      spotId: spot.spotId!, latitud: spot.latitud, longitud: spot.longitud);
    if (mounted && clima != null) {
      setState(() {
        _spots = _spots.map((s) => s.spotId == spot.spotId
            ? SpotModel(spotId: s.spotId, nombre: s.nombre, latitud: s.latitud,
                longitud: s.longitud, descripcion: s.descripcion, condiciones: clima)
            : s).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Spots'),
        actions: [
          IconButton(
            icon: Icon(_vistaLista ? Icons.map_outlined : Icons.list, color: SupColors.cyanNeon),
            onPressed: () => setState(() => _vistaLista = !_vistaLista),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: SupColors.cyanNeon), onPressed: _cargarSpots),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SupColors.cyanNeon, foregroundColor: SupColors.backgroundDeep,
        onPressed: _agregarSpot,
        child: const Icon(Icons.add),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon))
          : _vistaLista ? _buildLista() : _buildMapa(),
    );
  }

  Widget _buildLista() => RefreshIndicator(
    color: SupColors.cyanNeon, backgroundColor: SupColors.surface, onRefresh: _cargarSpots,
    child: ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 80),
      itemCount: _spots.length,
      itemBuilder: (_, i) => SpotCard(spot: _spots[i], onTap: () {}),
    ),
  );

  Widget _buildMapa() => FlutterMap(
    options: const MapOptions(initialCenter: LatLng(-38.0, -57.5), initialZoom: 6),
    children: [
      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.supready.app'),
      MarkerLayer(markers: _spots.map((spot) {
        final color = _colorIndice(spot.indiceViabilidad);
        return Marker(
          point: LatLng(spot.latitud, spot.longitud), width: 40, height: 40,
          child: GestureDetector(
            onTap: () => _mostrarInfoSpot(spot),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: color,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
              ),
              child: const Icon(Icons.surfing, color: Colors.white, size: 18),
            ),
          ),
        );
      }).toList()),
    ],
  );

  void _mostrarInfoSpot(SpotModel spot) {
    showModalBottomSheet(context: context, backgroundColor: SupColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SpotCard(spot: spot, onTap: null),
      ));
  }

  Color _colorIndice(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde: return SupColors.semaforoVerde;
      case SupReadyIndex.amarillo: return SupColors.semaforoAmarillo;
      case SupReadyIndex.rojo: return SupColors.semaforoRojo;
      case SupReadyIndex.sinDatos: return SupColors.textSecondary;
    }
  }
}

// ----------------------------------------------------------
// Sheet para agregar nuevo spot
// ----------------------------------------------------------
class _AgregarSpotSheet extends StatefulWidget {
  final Function(SpotModel) onGuardar;
  const _AgregarSpotSheet({required this.onGuardar});
  @override
  State<_AgregarSpotSheet> createState() => _AgregarSpotSheetState();
}

class _AgregarSpotSheetState extends State<_AgregarSpotSheet> {
  final _nombreCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  LatLng? _tapPos;

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: SupColors.textSecondary),
    filled: true, fillColor: SupColors.backgroundDeep,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SupColors.divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SupColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SupColors.cyanNeon, width: 1.5)),
  );

  void _guardar() {
    final nombre = _nombreCtrl.text.trim();
    final lat = double.tryParse(_latCtrl.text) ?? _tapPos?.latitude;
    final lon = double.tryParse(_lonCtrl.text) ?? _tapPos?.longitude;
    if (nombre.isEmpty || lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Completá nombre y coordenadas'), backgroundColor: SupColors.surface));
      return;
    }
    final spot = SpotModel(
      spotId: DateTime.now().millisecondsSinceEpoch % 100000,
      nombre: nombre, latitud: lat, longitud: lon, descripcion: _descCtrl.text.trim(),
    );
    widget.onGuardar(spot);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Spot agregado'), backgroundColor: SupColors.semaforoVerde));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: SupColors.divider, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        const Text('Agregar spot', style: SupTextStyles.heading2),
        const SizedBox(height: 16),
        TextField(controller: _nombreCtrl, style: const TextStyle(color: SupColors.textPrimary),
            decoration: _inputDeco('Nombre del spot')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _latCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: SupColors.textPrimary), decoration: _inputDeco('Latitud'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _lonCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: SupColors.textPrimary), decoration: _inputDeco('Longitud'))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _descCtrl, style: const TextStyle(color: SupColors.textPrimary),
            decoration: _inputDeco('Descripción (opcional)')),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _guardar, child: const Text('GUARDAR SPOT')),
      ]),
    );
  }
}
