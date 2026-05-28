import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/models/models.dart';

// ============================================================
// SUPReady - Onboarding (3 pasos, solo al primer uso)
// ============================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _pagina = 0;
  String _nombre = '';
  NivelExperiencia _nivel = NivelExperiencia.principiante;
  SpotModel? _spotFavorito;
  List<SpotModel> _spots = [];

  @override
  void initState() {
    super.initState();
    _cargarSpots();
  }

  Future<void> _cargarSpots() async {
    final spots = await SupDatabase.instance.getSpots();
    if (mounted) setState(() => _spots = spots);
  }

  Future<void> _finalizar() async {
    // Guardar nombre como usuario invitado
    if (_nombre.isNotEmpty) {
      final db = SupDatabase.instance;
      await db.upsertUsuario(UsuarioModel(
        nombre: _nombre, apellido: '', email: 'invitado@supready.local',
        nivelExperiencia: _nivel));
    }
    // Marcar spot favorito
    if (_spotFavorito?.spotId != null) {
      await SupDatabase.instance.setFavorito(_spotFavorito!.spotId!);
    }
    // Marcar onboarding como completado
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/home');
    // Rebuild home to reflect logged-in user if google login was done
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      body: SafeArea(
        child: Column(children: [
          // Progress dots
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _pagina ? 24 : 8, height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i == _pagina ? SupColors.cyanNeon : SupColors.divider,
                  borderRadius: BorderRadius.circular(4))))),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _pagina = p),
              children: [
                _Paso1Bienvenida(onNombre: (n) => setState(() => _nombre = n)),
                _Paso2Nivel(nivelActual: _nivel, onNivel: (n) => setState(() => _nivel = n)),
                _Paso3Spot(spots: _spots, spotActual: _spotFavorito,
                    onSpot: (s) => setState(() => _spotFavorito = s)),
              ],
            ),
          ),
          // Botones
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Row(children: [
              if (_pagina > 0)
                OutlinedButton(
                  onPressed: () {
                    _pageCtrl.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut);
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: SupColors.textSecondary,
                      side: const BorderSide(color: SupColors.divider),
                      minimumSize: const Size(80, 52)),
                  child: const Text('← Atrás'),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _pagina < 2
                      ? () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut)
                      : _finalizar,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: Text(_pagina < 2 ? 'SIGUIENTE →' : 'EMPEZAR A REMAR 🏄',
                      style: const TextStyle(fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Paso 1: Nombre ────────────────────────────────────────────
class _Paso1Bienvenida extends StatelessWidget {
  final ValueChanged<String> onNombre;
  const _Paso1Bienvenida({required this.onNombre});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🏄', style: TextStyle(fontSize: 72)),
      const SizedBox(height: 24),
      const Text('Bienvenido a\nSUPReady', style: SupTextStyles.heading1,
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      const Text('Tu compañero para remar seguro.\nCondiciones en tiempo real, GPS y comunidad.',
          style: SupTextStyles.body, textAlign: TextAlign.center),
      const SizedBox(height: 40),
      TextField(
        onChanged: onNombre,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(color: SupColors.textPrimary, fontSize: 18),
        decoration: InputDecoration(
          hintText: '¿Cómo te llamás?',
          hintStyle: const TextStyle(color: SupColors.textSecondary),
          filled: true, fillColor: SupColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SupColors.cyanNeon, width: 2)),
          prefixIcon: const Icon(Icons.person_outline, color: SupColors.cyanNeon)),
      ),
    ]),
  );
}

// ── Paso 2: Nivel ─────────────────────────────────────────────
class _Paso2Nivel extends StatelessWidget {
  final NivelExperiencia nivelActual;
  final ValueChanged<NivelExperiencia> onNivel;
  const _Paso2Nivel({required this.nivelActual, required this.onNivel});

  static const _niveles = [
    (nivel: NivelExperiencia.principiante, emoji: '🟢', label: 'Principiante',
     desc: 'Llevo poco tiempo, aguas tranquilas'),
    (nivel: NivelExperiencia.intermedio,   emoji: '🟡', label: 'Intermedio',
     desc: 'Ya manejo el remo con soltura'),
    (nivel: NivelExperiencia.avanzado,     emoji: '🔴', label: 'Avanzado',
     desc: 'Navego en cualquier condición'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('¿Cuál es tu nivel?', style: SupTextStyles.heading1,
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text('Lo usamos para filtrar salidas grupales\ny ajustar las alertas del semáforo.',
          style: SupTextStyles.body, textAlign: TextAlign.center),
      const SizedBox(height: 36),
      ..._niveles.map((n) => GestureDetector(
        onTap: () => onNivel(n.nivel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: nivelActual == n.nivel ? SupColors.cyanNeonDim : SupColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: nivelActual == n.nivel ? SupColors.cyanNeon : SupColors.divider,
              width: nivelActual == n.nivel ? 2 : 1)),
          child: Row(children: [
            Text(n.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.label, style: SupTextStyles.heading2.copyWith(fontSize: 17)),
              Text(n.desc, style: SupTextStyles.body.copyWith(fontSize: 13)),
            ])),
            if (nivelActual == n.nivel)
              const Icon(Icons.check_circle, color: SupColors.cyanNeon),
          ]),
        ),
      )),
    ]),
  );
}

// ── Paso 3: Spot favorito ─────────────────────────────────────
class _Paso3Spot extends StatelessWidget {
  final List<SpotModel> spots;
  final SpotModel? spotActual;
  final ValueChanged<SpotModel> onSpot;
  const _Paso3Spot({required this.spots, required this.spotActual, required this.onSpot});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('⭐', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 20),
      const Text('¿Tu spot favorito?', style: SupTextStyles.heading1,
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text('Lo verás en la pantalla de inicio\ncon el clima en tiempo real.',
          style: SupTextStyles.body, textAlign: TextAlign.center),
      const SizedBox(height: 32),
      if (spots.isEmpty)
        const CircularProgressIndicator(color: SupColors.cyanNeon)
      else
        ...spots.map((s) => GestureDetector(
          onTap: () => onSpot(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: spotActual?.spotId == s.spotId ? SupColors.cyanNeonDim : SupColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: spotActual?.spotId == s.spotId ? SupColors.cyanNeon : SupColors.divider,
                width: spotActual?.spotId == s.spotId ? 2 : 1)),
            child: Row(children: [
              const Icon(Icons.location_on_outlined, color: SupColors.cyanNeon, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.nombre, style: SupTextStyles.heading2.copyWith(fontSize: 15)),
                Text(s.descripcion, style: SupTextStyles.body.copyWith(fontSize: 12)),
              ])),
              if (spotActual?.spotId == s.spotId)
                const Icon(Icons.star_rounded, color: Colors.amber),
            ]),
          ),
        )),
    ]),
  );
}
