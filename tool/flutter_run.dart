import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_demo.dart';

Future<void> main(List<String> arguments) async {
  final keyFile = _findAmapKeyFile();
  if (keyFile == null) {
    stderr.writeln(
      'No Amap.csv found. Copy AmapExample.csv to Amap.csv and fill in your AMap keys.',
    );
    exit(1);
  }

  final keys = parseAmapLocalKeys(keyFile.readAsStringSync());

  if (keys.webJsKey == null || keys.webJsKey!.isEmpty) {
    stderr.writeln('Missing Wayfare_WebJS key in $keyFile');
    exit(1);
  }

  if (keys.webJsSecurityCode == null || keys.webJsSecurityCode!.isEmpty) {
    stderr.writeln(
      'Warning: Missing Security_code in $keyFile.\n'
      'AMap JS API 2.0 requires a security code. The map may fail to load.\n'
      'Add a line like "Security_code, <your_code>" to $keyFile.',
    );
  }

  final device =
      _optionValue(arguments, '-d') ??
      _optionValue(arguments, '--device-id') ??
      await _detectDevice();
  if (device == null) {
    stderr.writeln(
      'No supported device found. Connect a device or install Chrome/Edge.',
    );
    exit(1);
  }

  final apiBase = _optionValue(arguments, '--api-base');
  final defines = <String, String>{
    'AMAP_JS_KEY': keys.webJsKey!,
    if (keys.webJsSecurityCode case final code?) 'AMAP_JS_SECURITY_CODE': code,
    if (keys.androidKey case final key?) 'AMAP_ANDROID_KEY': key,
    if (keys.iosKey case final key?) 'AMAP_IOS_KEY': key,
    if (apiBase != null && apiBase.trim().isNotEmpty)
      'WAYFARE_API_BASE': apiBase.trim(),
    ..._dartDefinesFromArgs(arguments),
  };

  final tempDir = Directory.systemTemp.createTempSync('wayfare_defines_');
  final defineFile = File('${tempDir.path}/wayfare.env');
  final buffer = StringBuffer();
  for (final entry in defines.entries) {
    buffer.writeln('${entry.key}=${entry.value}');
  }
  defineFile.writeAsStringSync(buffer.toString());
  _writeIosLocalDartDefines(defines);

  final filteredArgs = _filterFlag(arguments, [
    '-d',
    '--device-id',
    '--api-base',
  ]);

  final runArgs = [
    'run',
    '-d',
    device,
    '--dart-define-from-file=${defineFile.path}',
    ...filteredArgs,
  ];

  stdout.writeln('Starting flutter run on device $device');
  stdout.writeln('  AMap keys loaded from $keyFile');
  if (defines['WAYFARE_API_BASE'] case final apiBase?) {
    stdout.writeln('  API base: $apiBase');
  }
  if (keys.webJsSecurityCode != null) {
    stdout.writeln('  Security code: present');
  } else {
    stdout.writeln('  Security code: MISSING — map may not load');
  }

  final process = await Process.start(
    Platform.isWindows ? 'cmd.exe' : 'flutter',
    Platform.isWindows ? ['/c', 'flutter', ...runArgs] : runArgs,
    mode: ProcessStartMode.inheritStdio,
    workingDirectory: Directory.current.path,
  );

  ProcessSignal.sigint.watch().listen((_) {
    tempDir.deleteSync(recursive: true);
    process.kill();
    exit(0);
  });

  final exitCode = await process.exitCode;
  tempDir.deleteSync(recursive: true);
  exit(exitCode);
}

Future<String?> _detectDevice() async {
  final process = await Process.start(
    Platform.isWindows ? 'cmd.exe' : 'flutter',
    Platform.isWindows
        ? ['/c', 'flutter', 'devices', '--machine']
        : ['devices', '--machine'],
    mode: ProcessStartMode.normal,
    workingDirectory: Directory.current.path,
  );
  final output = await process.stdout.transform(utf8.decoder).join();
  await process.exitCode;

  final devices = jsonDecode(output) as List;

  // Priority: Android > iOS > Web > any other.
  String? fallback;
  for (final d in devices) {
    final platform = d['targetPlatform'] as String? ?? '';
    if (platform.startsWith('android')) return d['id'] as String;
    if (platform.startsWith('ios')) return d['id'] as String;
    if (platform.startsWith('web-')) fallback ??= d['id'] as String;
  }
  return fallback ??
      (devices.isNotEmpty ? devices.first['id'] as String : null);
}

File? _findAmapKeyFile() {
  for (final path in const ['Amap.csv', '../Amap.csv']) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
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

Map<String, String> _dartDefinesFromArgs(List<String> args) {
  final defines = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String? raw;
    if (arg == '--dart-define' && i + 1 < args.length) {
      raw = args[++i];
    } else if (arg.startsWith('--dart-define=')) {
      raw = arg.substring('--dart-define='.length);
    }
    if (raw == null) {
      continue;
    }
    final separator = raw.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    defines[raw.substring(0, separator)] = raw.substring(separator + 1);
  }
  return defines;
}

void _writeIosLocalDartDefines(Map<String, String> defines) {
  final iosFlutterDir = Directory('ios/Flutter');
  if (!iosFlutterDir.existsSync()) {
    return;
  }

  final mergedDefines = <String, String>{
    ..._flutterGeneratedDefines(File('ios/Flutter/Generated.xcconfig')),
    ...defines,
  };
  final encoded = mergedDefines.entries
      .map((entry) => base64Encode(utf8.encode('${entry.key}=${entry.value}')))
      .join(',');
  File('${iosFlutterDir.path}/DartDefines.local.xcconfig').writeAsStringSync(
    '// Local dart-defines generated by tool/flutter_run.dart. Do not commit.\n'
    'DART_DEFINES=$encoded\n',
  );
}

Map<String, String> _flutterGeneratedDefines(File xcconfig) {
  if (!xcconfig.existsSync()) {
    return const {};
  }
  for (final line in xcconfig.readAsLinesSync()) {
    if (!line.startsWith('DART_DEFINES=')) {
      continue;
    }
    final defines = <String, String>{};
    for (final encoded in line.substring('DART_DEFINES='.length).split(',')) {
      if (encoded.isEmpty) {
        continue;
      }
      final decoded = utf8.decode(base64Decode(encoded));
      final separator = decoded.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = decoded.substring(0, separator);
      if (key.startsWith('FLUTTER_')) {
        defines[key] = decoded.substring(separator + 1);
      }
    }
    return defines;
  }
  return const {};
}

/// Remove [flags] and their values from [args] so they don't leak to Flutter.
List<String> _filterFlag(List<String> args, List<String> flags) {
  final result = <String>[];
  var skipNext = false;
  for (final arg in args) {
    if (skipNext) {
      skipNext = false;
      continue;
    }
    if (flags.contains(arg)) {
      skipNext = true;
      continue;
    }
    var matched = false;
    for (final flag in flags) {
      if (arg.startsWith('$flag=')) {
        matched = true;
        break;
      }
    }
    if (!matched) result.add(arg);
  }
  return result;
}
