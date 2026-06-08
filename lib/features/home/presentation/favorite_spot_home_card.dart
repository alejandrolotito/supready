import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../spots/data/favorite_spot_provider.dart';

class FavoriteSpotHomeCard extends ConsumerWidget {
  final String userId;
  const FavoriteSpotHomeCard({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spot = ref.watch(favoriteSpotProvider);
    if (spot == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text("Sin Spot Favorito asignado.", style: TextStyle(color: Colors.white38)),
      );
    }

    final Color tideColor = spot.tideTrend == "SUBIENDO" ? const Color(0xFF0284C7) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(spot.name.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFF0F172A),
                  child: Column(
                    children: [
                      const Icon(Icons.air_rounded, color: Color(0xFF38BDF8)),
                      Text("${spot.windSpeed} kts", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(spot.windDirection, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFF0F172A),
                  child: Column(
                    children: [
                      Icon(Icons.waves, color: tideColor),
                      Text("${spot.tideHeight} m", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(spot.tideTrend, style: TextStyle(fontSize: 11, color: tideColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
