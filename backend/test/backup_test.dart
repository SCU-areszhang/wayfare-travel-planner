import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../bin/backup.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wayfare_backup_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('creates a verified SQLite backup and manifest', () {
    final source = File('${tempDir.path}/wayfare.sqlite');
    _createDatabase(source);
    final backupDir = Directory('${tempDir.path}/backups');

    final result = createSqliteBackup(
      sourceDatabase: source,
      backupDirectory: backupDir,
      label: 'Wayfare Production',
      now: DateTime.utc(2026, 6, 8, 1, 2, 3),
    );

    expect(result.quickCheck, 'ok');
    expect(result.sourceDatabase, 'wayfare.sqlite');
    expect(result.sha256Hex, hasLength(64));
    expect(File(result.backupPath).existsSync(), isTrue);
    expect(File(result.manifestPath).existsSync(), isTrue);
    expect(result.backupPath,
        endsWith('wayfare-production-20260608T010203Z.sqlite'));
    expect(result.manifestPath,
        endsWith('wayfare-production-20260608T010203Z.manifest.json'));

    final manifest = jsonDecode(File(result.manifestPath).readAsStringSync())
        as Map<String, Object?>;
    expect(manifest['quickCheck'], 'ok');
    expect(manifest['sha256'], result.sha256Hex);
    expect(manifest['sizeBytes'], result.sizeBytes);

    final backup = sqlite3.open(result.backupPath);
    try {
      final rows = backup.select('SELECT name FROM destinations');
      expect(rows.single['name'], 'Hangzhou');
    } finally {
      backup.close();
    }
  });

  test('rejects missing and empty database files', () {
    final backupDir = Directory('${tempDir.path}/backups');

    expect(
      () => createSqliteBackup(
        sourceDatabase: File('${tempDir.path}/missing.sqlite'),
        backupDirectory: backupDir,
      ),
      throwsA(isA<FormatException>()),
    );

    final empty = File('${tempDir.path}/empty.sqlite')..createSync();
    expect(
      () => createSqliteBackup(
        sourceDatabase: empty,
        backupDirectory: backupDir,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

void _createDatabase(File file) {
  final database = sqlite3.open(file.path);
  try {
    database
        .execute('CREATE TABLE destinations (id TEXT PRIMARY KEY, name TEXT)');
    database.execute(
      'INSERT INTO destinations VALUES (?, ?)',
      ['dest-hangzhou', 'Hangzhou'],
    );
  } finally {
    database.close();
  }
}
