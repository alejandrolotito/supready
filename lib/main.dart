import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

<<<<<<< HEAD
  runApp(
    const ProviderScope(
      child: SupReadyApp(),
    ),
  );
=======
  // 2. Cargar preferencias locales rápido (sin esperar a la red)
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  // 3. Restaurar sesión de forma segura y sin bloquear la pantalla de carga principal
  try {
    await AuthService.instance.restaurarSesion().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint("Timeout al restaurar sesión");
        return false;
      },
    );
  } catch (e) {
    debugPrint("Error restaurando sesión: $e");
  }

  TrackingState.instance;

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  final tieneSession = AuthService.instance.estaAutenticado;
  final initialRoute = (!onboardingDone && !tieneSession) ? '/onboarding' : '/home';

  runApp(ProviderScope(child: SupReadyApp(initialRoute: initialRoute)));
>>>>>>> 0db7ef564c1e5b22065d0c91e2517fa88b1db45f
}

class SupReadyApp extends StatelessWidget {
  const SupReadyApp({Key? key}) : super(key: key);

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
