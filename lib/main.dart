import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/tracking_state.dart';
import 'data/datasources/remote/auth_service.dart';
import 'data/datasources/remote/firestore_service.dart';
import 'presentation/screens/tracking/tracking_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/spots/spots_screen.dart';
import 'presentation/screens/academy/academy_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/historial/historial_screen.dart';
import 'presentation/screens/prevision/prevision_screen.dart';
import 'presentation/screens/salidas/salidas_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializar Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Error inicializando Firebase: $e");
  }

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

  // Inicializar tablas Firestore de forma asíncrona en segundo plano para no congelar el splash screen
  FirestoreService.instance.generarTablasIniciales().catchError((e) {
    debugPrint("Error al generar tablas Firestore iniciales: $e");
  });

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
}

class SupReadyApp extends StatelessWidget {
  final String initialRoute;
  const SupReadyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'SUPReady',
        debugShowCheckedModeBanner: false,
        theme: SupTheme.darkTheme,
        routerConfig: _buildRouter(initialRoute),
      );
}

GoRouter _buildRouter(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: '/home',      builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/spots',     builder: (_, __) => const SpotsScreen()),
        GoRoute(path: '/track',     builder: (_, __) => const TrackingScreen()),
        GoRoute(path: '/prevision', builder: (_, __) => const PrevisionScreen()),
        GoRoute(path: '/salidas',   builder: (_, __) => const SalidasScreen()),
      ],
    ),
    GoRoute(path: '/historial', builder: (_, __) => const HistorialScreen()),
    GoRoute(path: '/profile',   builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/academy',   builder: (_, __) => const AcademyScreen()),
  ],
);

class _MainShell extends StatefulWidget {
  final Widget child;
  const _MainShell({required this.child});
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _idx = 0;

  static const _tabs = [
    (path: '/home',      icon: Icons.home_outlined,        selIcon: Icons.home,         label: 'Inicio'),
    (path: '/spots',     icon: Icons.location_on_outlined, selIcon: Icons.location_on,  label: 'Spots'),
    (path: '/track',     icon: Icons.surfing,              selIcon: Icons.surfing,       label: 'Remar'),
    (path: '/prevision', icon: Icons.wb_cloudy_outlined,   selIcon: Icons.wb_cloudy,     label: 'Tiempo'),
    (path: '/salidas',   icon: Icons.group_outlined,       selIcon: Icons.group,         label: 'Salidas'),
  ];

  static final _screens = [
    const HomeScreen(),
    const SpotsScreen(),
    const TrackingScreen(),
    const PrevisionScreen(),
    const SalidasScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Stack(children: [
        NavigationBar(
          backgroundColor: SupColors.surface,
          indicatorColor: SupColors.cyanNeonDim,
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: _tabs.map((t) => NavigationDestination(
            icon: Icon(t.icon, color: SupColors.textSecondary),
            selectedIcon: Icon(t.selIcon, color: SupColors.cyanNeon),
            label: t.label,
          )).toList(),
        ),
        _RecordingDot(tabCount: _tabs.length, activeTabIndex: 2),
      ]),
    );
  }
}

class _RecordingDot extends StatefulWidget {
  final int tabCount, activeTabIndex;
  const _RecordingDot({required this.tabCount, required this.activeTabIndex});
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    TrackingState.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    TrackingState.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!TrackingState.instance.activo) return const SizedBox.shrink();
    final tabW = MediaQuery.of(context).size.width / widget.tabCount;
    return Positioned(
      top: 6,
      left: tabW * widget.activeTabIndex + tabW / 2 + 8,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl),
        child: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SupColors.sosRed,
            boxShadow: [BoxShadow(
                color: SupColors.sosRed.withOpacity(0.7), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}
