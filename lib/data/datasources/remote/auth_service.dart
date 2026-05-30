import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../local/sup_database.dart';
import 'firestore_service.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  UsuarioModel? _usuarioActual;
  UsuarioModel? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // ─── Restaurar sesión al iniciar la app ─────────────────
  // Firebase Auth persists the session automatically between restarts.
  // We just need to load the UsuarioModel locally.
  Future<bool> restaurarSesion() async {
    try {
      // 1. Firebase already has an active session (persisted token)
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser?.email != null) {
        // Refresh token silently (no UI)
        await firebaseUser!.reload();

        // Try to fetch the user profile from Firestore
        _usuarioActual = await FirestoreService.instance
            ._obtenerUsuarioPorId(firebaseUser.uid);

        if (_usuarioActual != null) {
          return true;
        }

        // User exists in Firebase Auth but not in Firestore → rebuild locally
        final partes = (firebaseUser.displayName ?? 'Usuario').split(' ');
        final usuario = UsuarioModel(
          nombre: partes.first,
          apellido: partes.length > 1 ? partes.sublist(1).join(' ') : '',
          email: firebaseUser.email!,
          googleId: firebaseUser.uid,
          avatarUrl: firebaseUser.photoURL,
        );
        await SupDatabase.instance.upsertUsuario(usuario);
        _usuarioActual = await SupDatabase.instance
            .getUsuarioByEmail(firebaseUser.email!);
        return _usuarioActual != null;
      }

      // 2. Fallback: guest mode saved in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('last_email');
      if (email != null) {
        _usuarioActual = await SupDatabase.instance.getUsuarioByEmail(email);
        return _usuarioActual != null;
      }
    } catch (_) {
      // ignore errors, will return false
    }
    return false;
  }

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

      final userCred = await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCred.user;
      if (firebaseUser == null) return AuthResult.error('Usuario nulo');

      final partes = (firebaseUser.displayName ??
                googleUser.displayName ??
                'Usuario')
            .split(' ');
      final usuario = UsuarioModel(
        nombre: partes.first,
        apellido: partes.length > 1 ? partes.sublist(1).join(' ') : '',
        email: firebaseUser.email ?? googleUser.email,
        googleId: firebaseUser.uid,
        avatarUrl: firebaseUser.photoURL ?? googleUser.photoUrl,
      );

      // Persist locally
      await SupDatabase.instance.upsertUsuario(usuario);
      _usuarioActual = await SupDatabase.instance
          .getUsuarioByEmail(usuario.email);

      // Save email for fallback
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_email', usuario.email);

      return AuthResult.exitoso(_usuarioActual!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'sign_in_canceled') return AuthResult.cancelado();
      return AuthResult.error(e.message ?? e.code);
    } catch (e) {
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
        nombre: nombre,
        apellido: '',
        email: 'invitado@supready.local',
        googleId: null);
    await SupDatabase.instance.upsertUsuario(usuario);
    _usuarioActual = await SupDatabase.instance
        .getUsuarioByEmail('invitado@supready.local');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_email', 'invitado@supready.local');
  }

  // ─── Sign Out ────────────────────────────────────────────
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
    required this.exitoso,
    required this.cancelado,
    this.errorConfig = false,
    this.usuario,
    this.error,
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
