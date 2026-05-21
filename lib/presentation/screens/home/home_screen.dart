import 'package:flutter/material.dart';
import 'package:supready/core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SUPReady')),
      body: const Center(
        child: Text('Dashboard — próximamente', style: SupTextStyles.body),
      ),
    );
  }
}
