import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// IMPORTANTE: Asegúrate de crear esta carpeta y archivo más adelante
import 'widgets/score_card_widget.dart'; 
import 'features/home/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Conecta la app a los servicios de backend
  runApp(const ProviderScope(child: SupReadyApp()));
}

class SupReadyApp extends StatelessWidget {
  const SupReadyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'supReady',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF06B6D4),   // Cian Neón (Navegación / Tracks)
          secondary: Color(0xFF10B981), // Esmeralda (Comunidad / Salidas)
          surface: Color(0xFF1E293B),   // Slate 800 (Tarjetas / Contenedores)
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.black, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFF1F5F9)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
