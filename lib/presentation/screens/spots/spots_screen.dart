import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
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
    // Carga clima en paralelo para todos los spots
    final spotsConClima = await Future.wait<SpotModel>(spotsDB.map((s) async {
      final c = await ClimaService.instance.obtenerCondiciones(
          spotId: s.spotId!, latitud: s.latitud, longitud: s.longitud);
      return s.copyWith(condiciones: c);
    }));
    if (mounted) setState(() { _spots = spotsConClima; _cargando = false; });
  }

  void _agregarSpot() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: SupColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AgregarSpotSheet(onGuardar: (spot) async {
        final id = await SupDatabase.instance.insertarSpot(spot);
        final nuevo = SpotModel(spotId: id, nombre: spot.nombre, latitud: spot.latitud,
            longitud: spot.longitud, descripcion: spot.descripcion);
        final c = await ClimaService.instance.obtenerCondiciones(
            spotId: id, latitud: spot.latitud, longitud: spot.longitud);
        if (mounted) setState(() => _spots = [..._spots, nuevo.copyWith(condiciones: c)]);
      }),
    );
  }

  Future<void> _setFavorito(SpotModel spot) async {
    await SupDatabase.instance.setFavorito(spot.spotId!);
    if (mounted) setState(() {
      _spots = _spots.map((s) => s.copyWith(esFavorito: s.spotId == spot.spotId)).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${spot.nombre} es tu spot favorito'),
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
          ClimaService.instance.limpiarCache();
          _cargar();
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
      itemBuilder: (_, i) => SpotCard(
        spot: _spots[i], onTap: () {},
        onFavorito: () => _setFavorito(_spots[i]),
      ),
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
            onTap: () => showModalBottomSheet(context: context, backgroundColor: SupColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => Padding(padding: const EdgeInsets.all(20),
                  child: SpotCard(spot: s, onTap: null))),
            child: Stack(children: [
              Container(decoration: BoxDecoration(shape: BoxShape.circle, color: color,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]),
                  child: const Icon(Icons.surfing, color: Colors.white, size: 20)),
              if (s.esFavorito)
                Positioned(top: 0, right: 0,
                  child: Container(width: 12, height: 12,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amber))),
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

class _AgregarSpotSheet extends StatefulWidget {
  final Function(SpotModel) onGuardar;
  const _AgregarSpotSheet({required this.onGuardar});
  @override
  State<_AgregarSpotSheet> createState() => _AgregarSpotSheetState();
}

class _AgregarSpotSheetState extends State<_AgregarSpotSheet> {
  final _nombre = TextEditingController();
  final _lat    = TextEditingController();
  final _lon    = TextEditingController();
  final _desc   = TextEditingController();

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: SupColors.textSecondary),
    filled: true, fillColor: SupColors.backgroundDeep,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SupColors.divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SupColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SupColors.cyanNeon, width: 1.5)),
  );

  void _guardar() {
    final nombre = _nombre.text.trim();
    final lat = double.tryParse(_lat.text);
    final lon = double.tryParse(_lon.text);
    if (nombre.isEmpty || lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Completá nombre y coordenadas'), backgroundColor: SupColors.surface));
      return;
    }
    widget.onGuardar(SpotModel(nombre: nombre, latitud: lat, longitud: lon, descripcion: _desc.text.trim()));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: SupColors.divider, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      const Align(alignment: Alignment.centerLeft, child: Text('Agregar spot', style: SupTextStyles.heading2)),
      const SizedBox(height: 16),
      TextField(controller: _nombre, style: const TextStyle(color: SupColors.textPrimary), decoration: _deco('Nombre del spot')),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(color: SupColors.textPrimary), decoration: _deco('Latitud'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _lon, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(color: SupColors.textPrimary), decoration: _deco('Longitud'))),
      ]),
      const SizedBox(height: 12),
      TextField(controller: _desc, style: const TextStyle(color: SupColors.textPrimary), decoration: _deco('Descripción (opcional)')),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: _guardar, child: const Text('GUARDAR SPOT')),
    ]),
  );
}
