import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/spot_card/spot_card.dart';

class SpotsScreen extends StatelessWidget {
  const SpotsScreen({super.key});

  // Mock data para desarrollo
  static final _mockSpots = [
    SpotModel(
      spotId: 1, nombre: 'Playa Grande MDQ', latitud: -38.0055, longitud: -57.5426,
      descripcion: 'Mar del Plata - Spot principal',
      condiciones: CondicionesClimaticasModel(
        vientoKts: 6, rafagasKts: 8, olasMetros: 0.3,
        dirVientoGrados: 180, esOffshore: false, esCrossShore: false,
        actualizadoEn: DateTime.now(),
      ),
    ),
    SpotModel(
      spotId: 2, nombre: 'Punta Mogotes', latitud: -38.0700, longitud: -57.5300,
      descripcion: 'Mar del Plata Sur',
      condiciones: CondicionesClimaticasModel(
        vientoKts: 12, rafagasKts: 14, olasMetros: 0.6,
        dirVientoGrados: 90, esOffshore: false, esCrossShore: true,
        actualizadoEn: DateTime.now().subtract(const Duration(minutes: 35)),
      ),
    ),
    SpotModel(
      spotId: 3, nombre: 'Río de la Plata - Olivos', latitud: -34.5019, longitud: -58.4988,
      descripcion: 'Buenos Aires - Zona Norte',
      condiciones: CondicionesClimaticasModel(
        vientoKts: 20, rafagasKts: 25, olasMetros: 1.2,
        dirVientoGrados: 10, esOffshore: true, esCrossShore: false,
        actualizadoEn: DateTime.now(),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spots'),
        actions: [
          IconButton(icon: const Icon(Icons.map_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.add), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        itemCount: _mockSpots.length,
        itemBuilder: (context, i) => SpotCard(
          spot: _mockSpots[i],
          onTap: () {},
        ),
      ),
    );
  }
}
