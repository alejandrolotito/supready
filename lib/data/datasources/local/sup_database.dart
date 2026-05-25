import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/models.dart';

class SupDatabase {
  static final SupDatabase instance = SupDatabase._init();
  static Database? _db;
  SupDatabase._init();

  Future<Database> get database async => _db ??= await _initDB('supready.db');

  Future<Database> _initDB(String name) async {
    final path = join(await getDatabasesPath(), name);
    return openDatabase(path, version: 3, onCreate: _create, onUpgrade: _upgrade);
  }

  Future<void> _create(Database db, int v) async {
    await db.execute('''CREATE TABLE usuarios(
      usuario_id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL, apellido TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
      google_id TEXT UNIQUE, avatar_url TEXT,
      nivel_experiencia TEXT NOT NULL DEFAULT 'principiante')''');

    await db.execute('''CREATE TABLE spots(
      spot_id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL, latitud REAL NOT NULL, longitud REAL NOT NULL,
      descripcion TEXT DEFAULT '', es_favorito INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE rutas_trazadas(
      ruta_id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER NOT NULL, spot_id INTEGER NOT NULL,
      nombre_publico TEXT, es_publica INTEGER DEFAULT 0,
      distancia_total_km REAL DEFAULT 0, duracion_minutos INTEGER DEFAULT 0,
      velocidad_media REAL DEFAULT 0, velocidad_maxima REAL DEFAULT 0,
      iniciada_en TEXT NOT NULL, finalizada_en TEXT, sincronizado INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE coordenadas_ruta(
      coordenada_id INTEGER PRIMARY KEY AUTOINCREMENT,
      ruta_id INTEGER NOT NULL, latitud REAL NOT NULL, longitud REAL NOT NULL,
      secuencia INTEGER NOT NULL, velocidad_kmh REAL DEFAULT 0, timestamp TEXT NOT NULL)''');

    await db.execute('CREATE INDEX idx_coords ON coordenadas_ruta(ruta_id, secuencia)');

    await db.execute('''CREATE TABLE salidas_grupales(
      salida_id INTEGER PRIMARY KEY AUTOINCREMENT,
      organizador_id INTEGER NOT NULL, spot_id INTEGER NOT NULL,
      spot_nombre TEXT NOT NULL, fecha_hora TEXT NOT NULL,
      nivel_minimo TEXT DEFAULT 'todos', cupos_max INTEGER DEFAULT 10,
      es_publica INTEGER DEFAULT 1, estado TEXT DEFAULT 'abierta',
      descripcion TEXT DEFAULT '', sincronizado INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE salida_participantes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      salida_id INTEGER NOT NULL, usuario_id INTEGER NOT NULL,
      nombre TEXT NOT NULL, avatar_url TEXT, estado TEXT DEFAULT 'confirmado',
      UNIQUE(salida_id, usuario_id))''');

    // Spots iniciales
    await db.insert('spots', {'nombre': 'Playa Grande MDQ', 'latitud': -38.0055,
        'longitud': -57.5426, 'descripcion': 'Mar del Plata', 'es_favorito': 1});
    await db.insert('spots', {'nombre': 'Punta Mogotes', 'latitud': -38.0700,
        'longitud': -57.5300, 'descripcion': 'Mar del Plata Sur', 'es_favorito': 0});
    await db.insert('spots', {'nombre': 'Rio de la Plata - Olivos', 'latitud': -34.5019,
        'longitud': -58.4988, 'descripcion': 'Buenos Aires Norte', 'es_favorito': 0});
  }

  Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      try { await db.execute('ALTER TABLE coordenadas_ruta ADD COLUMN velocidad_kmh REAL DEFAULT 0'); } catch(_) {}
      try { await db.execute('ALTER TABLE spots ADD COLUMN es_favorito INTEGER DEFAULT 0'); } catch(_) {}
    }
    if (oldV < 3) {
      await db.execute('''CREATE TABLE IF NOT EXISTS salidas_grupales(
        salida_id INTEGER PRIMARY KEY AUTOINCREMENT,
        organizador_id INTEGER NOT NULL, spot_id INTEGER NOT NULL,
        spot_nombre TEXT NOT NULL, fecha_hora TEXT NOT NULL,
        nivel_minimo TEXT DEFAULT 'todos', cupos_max INTEGER DEFAULT 10,
        es_publica INTEGER DEFAULT 1, estado TEXT DEFAULT 'abierta',
        descripcion TEXT DEFAULT '', sincronizado INTEGER DEFAULT 0)''');
      await db.execute('''CREATE TABLE IF NOT EXISTS salida_participantes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        salida_id INTEGER NOT NULL, usuario_id INTEGER NOT NULL,
        nombre TEXT NOT NULL, avatar_url TEXT, estado TEXT DEFAULT 'confirmado',
        UNIQUE(salida_id, usuario_id))''');
    }
  }

  // ─── USUARIOS ──────────────────────────────────────────────
  Future<void> upsertUsuario(UsuarioModel u) async =>
      (await database).insert('usuarios', u.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<UsuarioModel?> getUsuarioByEmail(String email) async {
    final maps = await (await database).query('usuarios',
        where: 'email=?', whereArgs: [email], limit: 1);
    return maps.isEmpty ? null : UsuarioModel.fromMap(maps.first);
  }

  // ─── SPOTS ─────────────────────────────────────────────────
  Future<List<SpotModel>> getSpots() async {
    final maps = await (await database).query('spots',
        orderBy: 'es_favorito DESC, spot_id ASC');
    return maps.map(SpotModel.fromMap).toList();
  }

  Future<SpotModel?> getSpotFavorito() async {
    final maps = await (await database).query('spots',
        where: 'es_favorito=1', limit: 1);
    return maps.isEmpty ? null : SpotModel.fromMap(maps.first);
  }

  Future<int> insertarSpot(SpotModel spot) async =>
      (await database).insert('spots', spot.toMap());

  Future<void> setFavorito(int spotId) async {
    final db = await database;
    await db.update('spots', {'es_favorito': 0});
    await db.update('spots', {'es_favorito': 1},
        where: 'spot_id=?', whereArgs: [spotId]);
  }

  // ─── RUTAS ─────────────────────────────────────────────────
  Future<int> insertarRuta(RutaTrazadaModel r) async =>
      (await database).insert('rutas_trazadas', r.toMap());

  Future<void> actualizarRuta(RutaTrazadaModel r) async =>
      (await database).update('rutas_trazadas', r.toMap(),
          where: 'ruta_id=?', whereArgs: [r.rutaId]);

  Future<List<RutaTrazadaModel>> getRutasPorUsuario(int uid) async {
    final maps = await (await database).query('rutas_trazadas',
        where: 'usuario_id=?', whereArgs: [uid], orderBy: 'iniciada_en DESC');
    return maps.map(RutaTrazadaModel.fromMap).toList();
  }

  Future<List<RutaTrazadaModel>> getAllRutas() async {
    final maps = await (await database).query('rutas_trazadas',
        orderBy: 'iniciada_en DESC');
    return maps.map(RutaTrazadaModel.fromMap).toList();
  }

  Future<List<RutaTrazadaModel>> getRutasSinSincronizar() async {
    final maps = await (await database).query('rutas_trazadas',
        where: 'sincronizado=0 AND finalizada_en IS NOT NULL');
    return maps.map(RutaTrazadaModel.fromMap).toList();
  }

  Future<void> marcarRutaSincronizada(int id) async =>
      (await database).update('rutas_trazadas', {'sincronizado': 1},
          where: 'ruta_id=?', whereArgs: [id]);

  // ─── COORDENADAS ───────────────────────────────────────────
  Future<void> insertarCoordenada(CoordenadasRutaModel c) async =>
      (await database).insert('coordenadas_ruta', c.toMap());

  Future<List<CoordenadasRutaModel>> getCoordenadas(int rutaId) async {
    final maps = await (await database).query('coordenadas_ruta',
        where: 'ruta_id=?', whereArgs: [rutaId], orderBy: 'secuencia ASC');
    return maps.map(CoordenadasRutaModel.fromMap).toList();
  }

  // ─── SALIDAS GRUPALES ──────────────────────────────────────
  Future<int> crearSalida(SalidaGrupal s) async =>
      (await database).insert('salidas_grupales', s.toMap());

  Future<List<SalidaGrupal>> getSalidas({bool soloPublicas = false}) async {
    final db = await database;
    final where = soloPublicas
        ? "es_publica=1 AND estado!='cancelada'"
        : "estado!='cancelada'";
    final maps = await db.query('salidas_grupales',
        where: where, orderBy: 'fecha_hora ASC');
    final salidas = <SalidaGrupal>[];
    for (final m in maps) {
      final parts = await db.query('salida_participantes',
          where: 'salida_id=?', whereArgs: [m['salida_id']]);
      final participantes = parts.map((p) => ParticipanteSalida(
        usuarioId: p['usuario_id'] as int,
        nombre: p['nombre'] as String,
        avatarUrl: p['avatar_url'] as String?,
        estado: EstadoParticipante.values.firstWhere(
            (e) => e.name == p['estado'],
            orElse: () => EstadoParticipante.confirmado),
      )).toList();
      salidas.add(SalidaGrupal.fromMap(m).copyWithParticipantes(participantes));
    }
    return salidas;
  }

  Future<void> anotarseEnSalida(int salidaId, ParticipanteSalida p) async =>
      (await database).insert('salida_participantes', {
        'salida_id': salidaId, 'usuario_id': p.usuarioId,
        'nombre': p.nombre, 'avatar_url': p.avatarUrl, 'estado': p.estado.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> cancelarSalida(int salidaId) async =>
      (await database).update('salidas_grupales', {'estado': 'cancelada'},
          where: 'salida_id=?', whereArgs: [salidaId]);
}
