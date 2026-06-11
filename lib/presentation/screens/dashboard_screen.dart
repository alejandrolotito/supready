import 'package:flutter/material.dart';
import 'package:supready/core/theme/app_theme.dart';
import 'live_navigation_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dashboard Maestro', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Condiciones actuales', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const CircleAvatar(
                    backgroundColor: AppTheme.surfaceBright,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Métricas de Spot', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDim,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Viento', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondary)),
                                  const SizedBox(height: 8),
                                  RichText(
                                    text: const TextSpan(
                                      text: '12 ',
                                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.primary, fontFamily: 'Inter'),
                                      children: [
                                        TextSpan(text: 'kts NNE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDim,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Marea', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondary)),
                                  const SizedBox(height: 8),
                                  const Text('Subiendo', style: TextStyle(color: AppTheme.tideRising, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('Pico: 14:30 hs', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LiveNavigationScreen()),
                  );
                },
                child: const Text('INICIAR NAVEGACIÓN'),
              ),
              const SizedBox(height: 24),
              Text('Rutas Recientes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildRouteItem('Bahía Norte', 'Hace 2 días • 4.2 km', '52 min'),
                    const SizedBox(height: 8),
                    _buildRouteItem('Delta Sur', 'Hace 1 semana • 6.8 km', '1h 15m'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteItem(String title, String subtitle, String duration) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            ],
          ),
          Text(duration, style: const TextStyle(color: AppTheme.tertiary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
