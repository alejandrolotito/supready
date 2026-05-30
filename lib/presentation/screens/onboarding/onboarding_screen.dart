import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';
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
    // Guardar nombre como usuario invitado si no tiene cuenta de Google
    final usuarioAct = AuthService.instance.usuarioActual;
    if (usuarioAct == null && _nombre.isNotEmpty) {
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
                _Paso1Bienvenida(
                  onNombre: (n) => setState(() => _nombre = n),
                  onGoogleLoginSuccess: () {
                    // Pasar directamente al paso de selección de nivel
                    _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut);
                  },
                ),
                _Paso2Nivel(nivelActual: _nivel, onNivel: (n) => setState(() => _nivel = n)),
                _Paso3Spot(
                  spots: _spots,
                  spotActual: _spotFavorito,
                  onSpot: (s) => setState(() => _spotFavorito = s),
                  onSpotCreated: _cargarSpots,
                ),
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
class _Paso1Bienvenida extends StatefulWidget {
  final ValueChanged<String> onNombre;
  final VoidCallback onGoogleLoginSuccess;
  const _Paso1Bienvenida({required this.onNombre, required this.onGoogleLoginSuccess});

  @override
  State<_Paso1Bienvenida> createState() => _Paso1BienvenidaState();
}

class _Paso1BienvenidaState extends State<_Paso1Bienvenida> {
  bool _cargando = false;

  Future<void> _loginGoogle() async {
    setState(() => _cargando = true);
    final result = await AuthService.instance.signInConGoogle();
    setState(() => _cargando = false);
    if (!mounted) return;
    if (result.exitoso) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('¡Bienvenido ${result.usuario!.nombre}! 🏄'),
        backgroundColor: SupColors.semaforoVerde));
      widget.onGoogleLoginSuccess();
    } else if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error de autenticación: ${result.error}'),
        backgroundColor: SupColors.semaforoRojo));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: SingleChildScrollView(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 20),
        const Text('🏄', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 16),
        const Text('Bienvenido a\nSUPReady', style: SupTextStyles.heading1,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Tu compañero para remar seguro.\nCondiciones en tiempo real, GPS y comunidad.',
            style: SupTextStyles.body, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _cargando ? null : _loginGoogle,
          icon: _cargando
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: SupColors.backgroundDeep))
              : const Icon(Icons.login),
          label: Text(_cargando ? 'CONECTANDO...' : 'INICIAR CON GOOGLE'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: SupColors.cyanNeon,
            foregroundColor: SupColors.backgroundDeep,
          ),
        ),
        const SizedBox(height: 16),
        const Row(children: [
          Expanded(child: Divider(color: SupColors.divider)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('o ingresá como invitado', style: SupTextStyles.body)),
          Expanded(child: Divider(color: SupColors.divider)),
        ]),
        const SizedBox(height: 16),
        TextField(
          onChanged: widget.onNombre,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: SupColors.textPrimary, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Tu nombre',
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
        const SizedBox(height: 20),
      ]),
    ),
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
class _Paso3Spot extends StatefulWidget {
  final List<SpotModel> spots;
  final SpotModel? spotActual;
  final ValueChanged<SpotModel> onSpot;
  final VoidCallback onSpotCreated;
  const _Paso3Spot({
    required this.spots,
    required this.spotActual,
    required this.onSpot,
    required this.onSpotCreated,
  });

  @override
  State<_Paso3Spot> createState() => _Paso3SpotState();
}

class _Paso3SpotState extends State<_Paso3Spot> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  void _mostrarCrearSpot() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SupColors.surfaceElevated,
        title: const Text('Agregar Spot Personalizado',
            style: TextStyle(color: SupColors.textPrimary, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreCtrl,
                style: const TextStyle(color: SupColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nombre del Spot',
                  labelStyle: TextStyle(color: SupColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(color: SupColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Descripción / Ubicación',
                  labelStyle: TextStyle(color: SupColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: SupColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = _nombreCtrl.text.trim();
              final desc = _descCtrl.text.trim();
              if (nombre.isNotEmpty) {
                final nuevoSpot = SpotModel(
                  nombre: nombre,
                  descripcion: desc,
                  latitud: -34.6037, // Default coordinates (Buenos Aires / standard fallback)
                  longitud: -58.3816,
                  esFavorito: false,
                );
                final id = await SupDatabase.instance.insertarSpot(nuevoSpot);
                widget.onSpot(nuevoSpot.copyWith(esFavorito: false).copyWith(condiciones: null));
                widget.onSpotCreated();
                _nombreCtrl.clear();
                _descCtrl.clear();
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('AGREGAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('⭐', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 10),
      const Text('¿Tu spot favorito?', style: SupTextStyles.heading1,
          textAlign: TextAlign.center),
      const SizedBox(height: 6),
      const Text('Lo verás en la pantalla de inicio con el clima.',
          style: SupTextStyles.body, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      if (widget.spots.isEmpty)
        const CircularProgressIndicator(color: SupColors.cyanNeon)
      else
        ...widget.spots.take(3).map((s) => GestureDetector(
          onTap: () => widget.onSpot(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.spotActual?.spotId == s.spotId ? SupColors.cyanNeonDim : SupColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.spotActual?.spotId == s.spotId ? SupColors.cyanNeon : SupColors.divider,
                width: widget.spotActual?.spotId == s.spotId ? 2 : 1)),
            child: Row(children: [
              const Icon(Icons.location_on_outlined, color: SupColors.cyanNeon, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.nombre, style: SupTextStyles.heading2.copyWith(fontSize: 14)),
                Text(s.descripcion, style: SupTextStyles.body.copyWith(fontSize: 11)),
              ])),
              if (widget.spotActual?.spotId == s.spotId)
                const Icon(Icons.star_rounded, color: Colors.amber),
            ]),
          ),
        )),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _mostrarCrearSpot,
        icon: const Icon(Icons.add, color: SupColors.cyanNeon),
        label: const Text('AGREGAR OTRO SPOT', style: TextStyle(color: SupColors.cyanNeon, fontFamily: 'SpaceGrotesk')),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: SupColors.cyanNeon),
          minimumSize: const Size(double.infinity, 44),
        ),
      ),
    ]),
  );
}
