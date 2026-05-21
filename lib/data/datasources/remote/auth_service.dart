import 'package:google_sign_in/google_sign_in.dart';
import '../../data/models/models.dart';
import '../../data/datasources/local/sup_database.dart';

// ============================================================
// SUPReady - Servicio de Autenticación Google
// ERS RF4.1: OAuth 2.0 con Google Sign-In SDK
// ERS RF4.2: Extracción de nombre, apellido, email y avatar
// ERS RF4.3: Lógica Upsert para evitar duplicados
// ============================================================

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  UsuarioModel? _usuarioActual;
  UsuarioModel? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // --- Sign In con Google (ERS RF4.1) ---
  Future<AuthResult> signInConGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return AuthResult.cancelado();

      // ERS RF4.2: Extraer datos del perfil de Google
      final nombrePartes = account.displayName?.split(' ') ?? ['Usuario', ''];
      final nombre   = nombrePartes.isNotEmpty ? nombrePartes.first : 'Usuario';
      final apellido = nombrePartes.length > 1
          ? nombrePartes.sublist(1).join(' ')
          : '';

      final usuario = UsuarioModel(
        nombre: nombre,
        apellido: apellido,
        email: account.email,
        googleId: account.id,
        avatarUrl: account.photoUrl,
        nivelExperiencia: NivelExperiencia.principiante,
      );

      // ERS RF4.3: Upsert — crea o actualiza sin duplicar
      await SupDatabase.instance.upsertUsuario(usuario);
      final guardado = await SupDatabase.instance.getUsuarioByEmail(account.email);
      _usuarioActual = guardado;

      return AuthResult.exitoso(guardado!);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _usuarioActual = null;
  }

  // --- Restaurar sesión al abrir la app ---
  Future<bool> restaurarSesion() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;
      _usuarioActual = await SupDatabase.instance.getUsuarioByEmail(account.email);
      return _usuarioActual != null;
    } catch (_) {
      return false;
    }
  }
}

// ----------------------------------------------------------
// Result type para manejo de errores
// ----------------------------------------------------------
class AuthResult {
  final bool exitoso;
  final bool cancelado;
  final UsuarioModel? usuario;
  final String? error;

  const AuthResult._({
    required this.exitoso,
    required this.cancelado,
    this.usuario,
    this.error,
  });

  factory AuthResult.exitoso(UsuarioModel u) =>
      AuthResult._(exitoso: true, cancelado: false, usuario: u);

  factory AuthResult.cancelado() =>
      AuthResult._(exitoso: false, cancelado: true);

  factory AuthResult.error(String msg) =>
      AuthResult._(exitoso: false, cancelado: false, error: msg);
}
