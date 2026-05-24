import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../local/sup_database.dart';

// ============================================================
// SUPReady - Servicio de Autenticación
// 
// CONFIGURACIÓN REQUERIDA para Google Sign-In:
//   1. Crear proyecto en Firebase Console (console.firebase.google.com)
//   2. Agregar app Android con package: com.supready.app
//   3. Agregar SHA-1 del keystore (debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`)
//   4. Descargar google-services.json → android/app/
//   5. Habilitar Authentication → Google en Firebase Console
//
// Mientras no esté configurado, el modo invitado funciona sin login.
// ============================================================

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  UsuarioModel? _usuarioActual;
  UsuarioModel? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // ─── Sign In con Google ──────────────────────────────────
  Future<AuthResult> signInConGoogle() async {
    try {
      // Intentar login silencioso primero (sesión previa)
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) return AuthResult.cancelado();

      final partes = (account.displayName ?? 'Usuario').split(' ');
      final nombre   = partes.isNotEmpty ? partes.first : 'Usuario';
      final apellido = partes.length > 1 ? partes.sublist(1).join(' ') : '';

      final usuario = UsuarioModel(
        nombre: nombre, apellido: apellido,
        email: account.email, googleId: account.id,
        avatarUrl: account.photoUrl,
      );

      await SupDatabase.instance.upsertUsuario(usuario);
      _usuarioActual = await SupDatabase.instance.getUsuarioByEmail(account.email);

      // Guardar email para restaurar sesión
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_email', account.email);

      return AuthResult.exitoso(_usuarioActual!);
    } on Exception catch (e) {
      // Google Sign-In no configurado → mensaje claro
      final msg = e.toString();
      if (msg.contains('sign_in_failed') || msg.contains('ApiException') || 
          msg.contains('10:') || msg.contains('DEVELOPER_ERROR')) {
        return AuthResult.errorConfiguracion();
      }
      return AuthResult.error(msg);
    }
  }

  // ─── Modo invitado (sin login) ───────────────────────────
  Future<void> entrarComoInvitado(String nombre) async {
    final usuario = UsuarioModel(
      nombre: nombre, apellido: '', email: 'invitado@supready.local',
    );
    await SupDatabase.instance.upsertUsuario(usuario);
    _usuarioActual = await SupDatabase.instance.getUsuarioByEmail('invitado@supready.local');
  }

  // ─── Restaurar sesión al abrir la app ───────────────────
  Future<bool> restaurarSesion() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _usuarioActual = await SupDatabase.instance.getUsuarioByEmail(account.email);
        return _usuarioActual != null;
      }
      // Intentar restaurar invitado
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('last_email');
      if (email != null) {
        _usuarioActual = await SupDatabase.instance.getUsuarioByEmail(email);
        return _usuarioActual != null;
      }
    } catch (_) {}
    return false;
  }

  Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_email');
    _usuarioActual = null;
  }
}

class AuthResult {
  final bool exitoso, cancelado, errorConfig;
  final UsuarioModel? usuario;
  final String? error;

  const AuthResult._({
    required this.exitoso, required this.cancelado,
    this.errorConfig = false, this.usuario, this.error,
  });

  factory AuthResult.exitoso(UsuarioModel u) =>
      AuthResult._(exitoso: true, cancelado: false, usuario: u);
  factory AuthResult.cancelado() =>
      AuthResult._(exitoso: false, cancelado: true);
  factory AuthResult.errorConfiguracion() =>
      AuthResult._(exitoso: false, cancelado: false, errorConfig: true);
  factory AuthResult.error(String msg) =>
      AuthResult._(exitoso: false, cancelado: false, error: msg);
}
