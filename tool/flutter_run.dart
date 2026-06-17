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

  final device = _optionValue(arguments, '-d') ??
      _optionValue(arguments, '--device-id') ??
      await _detectDevice();
  if (device == null) {
    stderr.writeln('No supported device found. Connect a device or install Chrome/Edge.');
    exit(1);
  }

  final tempDir = Directory.systemTemp.createTempSync('wayfare_defines_');
  final defineFile = File('${tempDir.path}/amap.env');
  final buffer = StringBuffer()
    ..writeln('AMAP_JS_KEY=${keys.webJsKey}');
  if (keys.webJsSecurityCode case final code?) {
    buffer.writeln('AMAP_JS_SECURITY_CODE=$code');
  }
  if (keys.androidKey case final key?) {
    buffer.writeln('AMAP_ANDROID_KEY=$key');
  }
  if (keys.iosKey case final key?) {
    buffer.writeln('AMAP_IOS_KEY=$key');
  }
  defineFile.writeAsStringSync(buffer.toString());

  final filteredArgs = _filterFlag(arguments, ['-d', '--device-id']);

  final runArgs = [
    'run',
    '-d',
    device,
    '--dart-define-from-file=${defineFile.path}',
    ...filteredArgs,
  ];

  stdout.writeln('Starting flutter run on device $device');
  stdout.writeln('  AMap keys loaded from $keyFile');
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
  return fallback ?? (devices.isNotEmpty ? devices.first['id'] as String : null);
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
