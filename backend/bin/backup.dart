import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> arguments) {
  try {
    final options = BackupOptions.fromArguments(
      arguments,
      Platform.environment,
      Directory.current,
    );
    final result = createSqliteBackup(
      sourceDatabase: File(options.databasePath),
      backupDirectory: Directory(options.backupDirectory),
      label: options.label,
    );
    stdout.write(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    stdout.writeln();
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

class BackupOptions {
  const BackupOptions({
    required this.databasePath,
    required this.backupDirectory,
    required this.label,
  });

  factory BackupOptions.fromArguments(
    List<String> arguments,
    Map<String, String> environment,
    Directory workingDirectory,
  ) {
    final databasePath = _optionValue(arguments, '--database') ??
        environment['WAYFARE_DB_PATH'] ??
        'data/wayfare.sqlite';
    final backupDirectory = _optionValue(arguments, '--backup-dir') ??
        environment['WAYFARE_BACKUP_DIR'] ??
        'backups';
    final label = _optionValue(arguments, '--label') ?? 'wayfare';
    return BackupOptions(
      databasePath: _absolutePath(workingDirectory, databasePath),
      backupDirectory: _absolutePath(workingDirectory, backupDirectory),
      label: _safeLabel(label),
    );
  }

  final String databasePath;
  final String backupDirectory;
  final String label;
}

class BackupResult {
  const BackupResult({
    required this.createdAt,
    required this.sourceDatabase,
    required this.backupPath,
    required this.manifestPath,
    required this.sizeBytes,
    required this.sha256Hex,
    required this.quickCheck,
  });

  final DateTime createdAt;
  final String sourceDatabase;
  final String backupPath;
  final String manifestPath;
  final int sizeBytes;
  final String sha256Hex;
  final String quickCheck;

  Map<String, Object?> toJson() {
    return {
      'createdAt': createdAt.toUtc().toIso8601String(),
      'sourceDatabase': sourceDatabase,
      'backupPath': backupPath,
      'manifestPath': manifestPath,
      'sizeBytes': sizeBytes,
      'sha256': sha256Hex,
      'quickCheck': quickCheck,
    };
  }
}

BackupResult createSqliteBackup({
  required File sourceDatabase,
  required Directory backupDirectory,
  String label = 'wayfare',
  DateTime? now,
}) {
  if (!sourceDatabase.existsSync()) {
    throw FormatException('Database does not exist: ${sourceDatabase.path}');
  }
  if (sourceDatabase.lengthSync() == 0) {
    throw FormatException('Database is empty: ${sourceDatabase.path}');
  }

  final quickCheck = _quickCheck(sourceDatabase);
  if (quickCheck != 'ok') {
    throw FormatException('Database quick_check failed: $quickCheck');
  }

  backupDirectory.createSync(recursive: true);
  final createdAt = (now ?? DateTime.now()).toUtc();
  final filenameBase =
      '${_safeLabel(label)}-${_timestampForFilename(createdAt)}';
  final backupFile = File('${backupDirectory.path}/$filenameBase.sqlite');
  final manifestFile =
      File('${backupDirectory.path}/$filenameBase.manifest.json');
  if (backupFile.existsSync() || manifestFile.existsSync()) {
    throw FormatException('Backup already exists for timestamp: $filenameBase');
  }

  final database = sqlite3.open(sourceDatabase.path);
  try {
    database.execute("VACUUM INTO '${_sqliteStringLiteral(backupFile.path)}'");
  } finally {
    database.close();
  }

  final backupQuickCheck = _quickCheck(backupFile);
  if (backupQuickCheck != 'ok') {
    throw FormatException('Backup quick_check failed: $backupQuickCheck');
  }

  final digest = sha256.convert(backupFile.readAsBytesSync()).toString();
  final result = BackupResult(
    createdAt: createdAt,
    sourceDatabase: sourceDatabase.uri.pathSegments.isEmpty
        ? sourceDatabase.path
        : sourceDatabase.uri.pathSegments.last,
    backupPath: backupFile.path,
    manifestPath: manifestFile.path,
    sizeBytes: backupFile.lengthSync(),
    sha256Hex: digest,
    quickCheck: backupQuickCheck,
  );
  manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result.toJson())}\n',
  );
  return result;
}

String _quickCheck(File databaseFile) {
  final database = sqlite3.open(databaseFile.path);
  try {
    final result = database.select('PRAGMA quick_check');
    if (result.isEmpty) {
      return 'empty quick_check result';
    }
    return result.first.values.first.toString();
  } finally {
    database.close();
  }
}

String? _optionValue(List<String> arguments, String name) {
  for (var index = 0; index < arguments.length; index++) {
    final value = arguments[index];
    if (value == name && index + 1 < arguments.length) {
      return arguments[index + 1];
    }
    if (value.startsWith('$name=')) {
      return value.substring(name.length + 1);
    }
  }
  return null;
}

String _absolutePath(Directory workingDirectory, String path) {
  if (path.startsWith('/')) {
    return path;
  }
  return '${workingDirectory.path}/$path';
}

String _safeLabel(String label) {
  final normalized = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_.-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  if (normalized.isEmpty) {
    return 'wayfare';
  }
  return normalized.length > 40 ? normalized.substring(0, 40) : normalized;
}

String _timestampForFilename(DateTime value) {
  final utc = value.toUtc();
  String two(int input) => input.toString().padLeft(2, '0');
  return '${utc.year}'
      '${two(utc.month)}'
      '${two(utc.day)}T'
      '${two(utc.hour)}'
      '${two(utc.minute)}'
      '${two(utc.second)}Z';
}

String _sqliteStringLiteral(String value) {
  return value.replaceAll("'", "''");
}
