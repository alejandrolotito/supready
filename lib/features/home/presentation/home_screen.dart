import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'favorite_spot_home_card.dart';
import '../../tracking/presentation/sup_water_map_widget.dart';
import '../../trips/presentation/trips_list_screen.dart';
import '../../spots/presentation/add_spot_form_screen.dart';
import '../../spots/data/favorite_spot_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Start listening to user's favorite spot
    ref.read(favoriteSpotProvider.notifier).listenToFavoriteSpot("rider_pro_123");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("supReady MASTER"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt, color: Color(0xFF10B981)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddSpotFormScreen())),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FavoriteSpotHomeCard(userId: "rider_pro_123"),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), padding: const EdgeInsets.symmetric(vertical: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupWaterMapWidget())),
              icon: const Icon(Icons.navigation_rounded, color: Colors.white),
              label: const Text("NUEVA NAVEGACIÓN (GPS 3s)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TripsListScreen())),
              icon: const Icon(Icons.groups_rounded, color: Colors.white),
              label: const Text("SALIDAS DE LA COMUNIDAD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
