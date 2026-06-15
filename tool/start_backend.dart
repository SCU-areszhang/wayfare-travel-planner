import 'dart:io';

import 'local_demo.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write('''
Usage: dart run tool/start_backend.dart [options]

Options:
  --port <port>   Server port, default 8080.
  --host <host>   Bind host, default 0.0.0.0.
  --db <path>     SQLite database path, default data/wayfare.sqlite.

Reads AMAP_WEB_SERVICE_KEY from Amap.csv automatically.
''');
    return;
  }

  final port = _optionValue(args, '--port') ?? '8080';
  final host = _optionValue(args, '--host') ?? '0.0.0.0';
  final dbPath = _optionValue(args, '--db') ?? 'data/wayfare.sqlite';

  final backendDir = Directory('backend');
  if (!backendDir.existsSync()) {
    stderr.writeln('Missing backend/ directory. Run from project root.');
    exit(1);
  }

  final keyFile = _findAmapKeyFile();
  final webSvcKey = keyFile != null
      ? parseAmapLocalKeys(keyFile.readAsStringSync()).webServiceKey
      : null;

  final env = {
    'PORT': port,
    'WAYFARE_BIND_HOST': host,
    'WAYFARE_DB_PATH': dbPath,
    'WAYFARE_AUTH_SECRET': 'dev-secret',
    'WAYFARE_OPS_TOKEN': 'dev-ops-token',
    if (webSvcKey != null) 'AMAP_WEB_SERVICE_KEY': webSvcKey,
  };

  stdout.writeln('Starting backend on $host:$port');
  if (webSvcKey != null) stdout.writeln('  AMap Web Service key loaded from Amap.csv');

  final process = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'bin/server.dart'],
    workingDirectory: backendDir.path,
    environment: env,
    mode: ProcessStartMode.inheritStdio,
  );

  ProcessSignal.sigint.watch().listen((_) {
    process.kill();
    exit(0);
  });

  final code = await process.exitCode;
  exit(code);
}

File? _findAmapKeyFile() {
  for (final path in const ['Amap.csv', '../Amap.csv']) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

String? _optionValue(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == name && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$name=')) return args[i].substring(name.length + 1);
  }
  return null;
}
