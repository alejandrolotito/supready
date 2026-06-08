import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong2.dart';
import '../data/favorite_spot_provider.dart';

class AddSpotFormScreen extends ConsumerStatefulWidget {
  const AddSpotFormScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<AddSpotFormScreen> createState() => _AddSpotFormScreenState();
}

class _AddSpotFormScreenState extends ConsumerState<AddSpotFormScreen> {
  final _nameController = TextEditingController();
  LatLng _selectedLocation = const LatLng(-37.7472, -57.4278); // Mar Chiquita base de ejemplo

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CREAR SPOT")),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 12.0,
                onTap: (pos, point) => setState(() => _selectedLocation = point),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.supready.app'),
                MarkerLayer(markers: [Marker(point: _selectedLocation, child: const Icon(Icons.location_on, color: Colors.red, size: 40))]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Nombre del Spot")),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) return;
                    await ref.read(favoriteSpotProvider.notifier).addNewSpot(
                      name: _nameController.text, lat: _selectedLocation.latitude, lng: _selectedLocation.longitude, creatorId: "rider_pro_123",
                    );
                    Navigator.pop(context);
                  },
                  child: const Text("GUARDAR EN FIREBASE"),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
