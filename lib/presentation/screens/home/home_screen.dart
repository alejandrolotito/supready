// ============================================================
// SUPReady - Pantallas stub (scaffolds listos para implementar)
// ============================================================
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// HOME
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SUPReady')),
    body: const Center(child: Text('Dashboard — próximamente', style: SupTextStyles.body)),
  );
}
