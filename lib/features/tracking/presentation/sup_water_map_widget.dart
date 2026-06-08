import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong2.dart';
import '../data/tracking_provider.dart';

class SupWaterMapWidget extends ConsumerStatefulWidget {
  const SupWaterMapWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<SupWaterMapWidget> createState() => _SupWaterMapWidgetState();
}

class _SupWaterMapWidgetState extends ConsumerState<SupWaterMapWidget> with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();
  bool _mapSiguePosicion = true;
  late AnimationController _longPressCtrl;
  bool _longPressActivo = false;

  @override
  void initState() {
    super.initState();
    _longPressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finalizarTracking();
        }
      });
  }

  @override
  void dispose() {
    _longPressCtrl.dispose();
    super.dispose();
  }

  void _iniciarTracking() {
    HapticFeedback.heavyImpact();
    ref.read(trackingProvider.notifier).startTracking("rider_pro_123");
  }

  void _finalizarTracking() {
    HapticFeedback.heavyImpact();
    ref.read(trackingProvider.notifier).stopTracking("rider_pro_123");
    _longPressCtrl.reset();
    setState(() {
      _longPressActivo = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Navegación guardada en Firebase"),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    final points = tracking.routePoints;
    final hasPoints = points.isNotEmpty;

    LatLng mapCenter = const LatLng(-38.0, -57.5); // Default MDQ coordinates
    if (hasPoints) {
      mapCenter = LatLng(points.last.latitude, points.last.longitude);
      if (_mapSiguePosicion) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapCtrl.move(mapCenter, _mapCtrl.camera.zoom);
        });
      }
    }

    // Calcular distancia y velocidad promedio simples
    double totalDistance = 0.0;
    double currentSpeedKnots = 0.0;
    if (hasPoints) {
      currentSpeedKnots = points.last.speed * 1.94384; // m/s a knots
      if (currentSpeedKnots < 0) currentSpeedKnots = 0.0;
      
      // Distancia acumulada (aproximación simplificada)
      for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        totalDistance += Distance().as(
          LengthUnit.Kilometer,
          LatLng(p1.latitude, p1.longitude),
          LatLng(p2.latitude, p2.longitude),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("NAVEGACIÓN SUP"),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          if (tracking.isTracking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("REC", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _mapSiguePosicion) {
                  setState(() => _mapSiguePosicion = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.supready.app',
              ),
              if (points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                      color: const Color(0xFF06B6D4),
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              if (hasPoints)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: mapCenter,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Recentrar mapa
          if (!_mapSiguePosicion && hasPoints)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF06B6D4),
                mini: true,
                onPressed: () {
                  setState(() => _mapSiguePosicion = true);
                  _mapCtrl.move(mapCenter, 15.0);
                },
                child: const Icon(Icons.my_location),
              ),
            ),

          // Panel de métricas y controles
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Métricas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem("VELOCIDAD", "${currentSpeedKnots.toStringAsFixed(1)} kts"),
                      _buildMetricItem("DISTANCIA", "${totalDistance.toStringAsFixed(2)} km"),
                      _buildMetricItem("PUNTOS", "${points.length}"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Botón de acción principal
                  if (!tracking.isTracking)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _iniciarTracking,
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text("INICIAR REMADA", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    )
                  else
                    GestureDetector(
                      onLongPressStart: (_) {
                        setState(() => _longPressActivo = true);
                        _longPressCtrl.forward();
                      },
                      onLongPressEnd: (_) {
                        if (_longPressCtrl.status != AnimationStatus.completed) {
                          _longPressCtrl.reset();
                          setState(() => _longPressActivo = false);
                        }
                      },
                      child: AnimatedBuilder(
                        animation: _longPressCtrl,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF475569)),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  "MANTENER PARA DETENER",
                                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (_longPressActivo)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: _longPressCtrl.value,
                                      child: Container(
                                        height: 58,
                                        color: const Color(0xFFEF4444).withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono')),
      ],
    );
  }
}
