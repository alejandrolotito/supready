import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../local/sup_database.dart';

// ============================================================
// SUPReady - Servicio de Autenticación con Firebase Auth
// Proyecto: SupReady (supready) — Número: 82783760497
// ============================================================

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _firebaseAuth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  UsuarioModel? _usuarioActual;
  UsuarioModel? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // ─── Sign In con Google + Firebase ──────────────────────
  Future<AuthResult> signInConGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return AuthResult.cancelado();

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return AuthResult.error('Firebase user null');

      final partes = (firebaseUser.displayName ?? 'Usuario').split(' ');
      final nombre   = partes.isNotEmpty ? partes.first : 'Usuario';
      final apellido = partes.length > 1 ? partes.sublist(1).join(' ') : '';

      final usuario = UsuarioModel(
        nombre: nombre, apellido: apellido,
        email: firebaseUser.email ?? googleUser.email,
        googleId: firebaseUser.uid,
        avatarUrl: firebaseUser.photoURL,
      );

      await SupDatabase.instance.upsertUsuario(usuario);
      _usuarioActual = await SupDatabase.instance
          .getUsuarioByEmail(usuario.email);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_email', usuario.email);

      return AuthResult.exitoso(_usuarioActual!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'sign_in_canceled') return AuthResult.cancelado();
      return AuthResult.error(e.message ?? e.code);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('ApiException: 10') ||
          msg.contains('DEVELOPER_ERROR') ||
          msg.contains('sign_in_failed')) {
        return AuthResult.errorConfiguracion();
      }
      return AuthResult.error(msg);
    }
  }

  // ─── Modo invitado ───────────────────────────────────────
  Future<void> entrarComoInvitado(String nombre) async {
    final usuario = UsuarioModel(
        nombre: nombre, apellido: '', email: 'invitado@supready.local');
    await SupDatabase.instance.upsertUsuario(usuario);
    _usuarioActual = await SupDatabase.instance
        .getUsuarioByEmail('invitado@supready.local');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_email', 'invitado@supready.local');
  }

  // ─── Restaurar sesión al abrir ───────────────────────────
  Future<bool> restaurarSesion() async {
    try {
      // Firebase mantiene la sesión automáticamente
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser?.email != null) {
        _usuarioActual = await SupDatabase.instance
            .getUsuarioByEmail(firebaseUser!.email!);
        if (_usuarioActual != null) return true;
      }
      // Fallback: invitado desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('last_email');
      if (email != null) {
        _usuarioActual =
            await SupDatabase.instance.getUsuarioByEmail(email);
        return _usuarioActual != null;
      }
    } catch (_) {}
    return false;
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (_) {}
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
