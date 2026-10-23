import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

/// Acceso a PostgreSQL para todo el backend.
///
/// La conexión se configura de una de estas dos formas:
///
/// 1. `DATABASE_URL` (despliegue en Render, Neon, Heroku, etc.):
///    `postgresql://usuario:clave@host:5432/base?sslmode=require`
///    Si la base no es local y la URL no dice `sslmode`, se usa SSL.
/// 2. Si no hay `DATABASE_URL`, las variables `DB_HOST`, `DB_PORT`,
///    `DB_NAME`, `DB_USER` y `DB_PASS` (desarrollo local, en `backend/.env`).
///    En local no se usa SSL.
///
/// Se usa un pool de conexiones en vez de una sola conexión: si la base de
/// datos cierra una conexión (Neon suspende la base tras unos minutos sin
/// uso, o PostgreSQL se reinicia), el pool abre otra sola y el servidor no
/// queda caído.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Pool? _pool;
  late DotEnv env;

  Future<void> init() async {
    // `quiet`: en Render no existe el archivo .env (las variables vienen
    // del panel), así que no se muestra el aviso "file not found".
    env = DotEnv(includePlatformEnvironment: true, quiet: true)..load();

    final destino = _leerConfiguracion();
    _pool = Pool.withEndpoints(
      [destino.endpoint],
      settings: PoolSettings(
        maxConnectionCount: 5,
        sslMode: destino.sslMode,
      ),
    );

    try {
      // Consulta de prueba: si la clave o el host están mal, el error
      // aparece al arrancar y no en la primera visita al sitio.
      await _pool!.execute('SELECT 1');
      print('✅ Conectado exitosamente a PostgreSQL '
          '(${destino.endpoint.database} en ${destino.endpoint.host}:${destino.endpoint.port})');
    } catch (e) {
      print('⚠️ Error al conectar a PostgreSQL: $e');
      rethrow;
    }
  }

  ({Endpoint endpoint, SslMode sslMode}) _leerConfiguracion() {
    final url = env['DATABASE_URL']?.trim() ?? '';
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      final credenciales = uri.userInfo.split(':');
      final usuario = Uri.decodeComponent(credenciales.first);
      final clave = credenciales.length > 1
          ? Uri.decodeComponent(credenciales.sublist(1).join(':'))
          : null;
      final base = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      final esLocal = uri.host == 'localhost' || uri.host == '127.0.0.1';
      final sslPedido = uri.queryParameters['sslmode'];
      final ssl = sslPedido == null
          ? (esLocal ? SslMode.disable : SslMode.require)
          : (sslPedido == 'disable' ? SslMode.disable : SslMode.require);
      return (
        endpoint: Endpoint(
          host: uri.host,
          port: uri.hasPort ? uri.port : 5432,
          database: base,
          username: usuario.isEmpty ? null : usuario,
          password: clave,
        ),
        sslMode: ssl,
      );
    }

    return (
      endpoint: Endpoint(
        host: env['DB_HOST'] ?? 'localhost',
        port: int.tryParse(env['DB_PORT'] ?? '5432') ?? 5432,
        database: env['DB_NAME'] ?? 'maykel_repuestos_db',
        username: env['DB_USER'] ?? 'postgres',
        password: env['DB_PASS'] ?? 'postgres',
      ),
      sslMode: SslMode.disable,
    );
  }

  /// Pool de conexiones. Tiene los mismos `execute` y `runTx` que una
  /// conexión, así que el resto del servidor no cambia.
  Pool get conn {
    final pool = _pool;
    if (pool == null) {
      throw StateError('La conexión a PostgreSQL no está inicializada.');
    }
    return pool;
  }
}
