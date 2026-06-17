import 'dart:io';

import 'local_demo.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.write('''
Usage: dart run tool/build_android.dart [options]

Options:
  --api-base <url>   Backend URL, default auto-detected LAN IP on port 8080.

Reads AMap keys from Amap.csv automatically.
''');
    return;
  }

  final keyFile = _findAmapKeyFile();
  if (keyFile == null) {
    stderr.writeln('No Amap.csv found. Copy AmapExample.csv to Amap.csv and fill in your AMap keys.');
    exit(1);
  }

  final keys = parseAmapLocalKeys(keyFile.readAsStringSync());
  final apiBase = _optionValue(arguments, '--api-base') ?? await _detectLocalApiBase();

  if (keys.androidKey == null || keys.androidKey!.isEmpty) {
    stderr.writeln('Missing Wayfare_Android key in $keyFile. Android build requires an AMap Android key.');
    exit(1);
  }

  final defines = <String, String>{
    'WAYFARE_API_BASE': apiBase,
    if (keys.webJsKey case final k?) 'AMAP_JS_KEY': k,
    if (keys.webJsSecurityCode case final k?) 'AMAP_JS_SECURITY_CODE': k,
    'AMAP_ANDROID_KEY': keys.androidKey!,
    if (keys.iosKey case final k?) 'AMAP_IOS_KEY': k,
  };

  stdout.writeln('Building Android APK with keys from $keyFile');
  for (final entry in defines.entries) {
    final masked = entry.value.length > 6
        ? '${entry.value.substring(0, 3)}***${entry.value.substring(entry.value.length - 3)}'
        : '***';
    stdout.writeln('  ${entry.key}=$masked');
  }

  final filteredArgs = _filterCustomArgs(arguments, ['--api-base']);

  final buildArgs = <String>[
    'build', 'apk', '--release', '--split-per-abi', '--no-pub',
    for (final entry in defines.entries)
      '--dart-define=${entry.key}=${entry.value}',
    ...filteredArgs,
  ];

  final process = await Process.start(
    Platform.isWindows ? 'cmd.exe' : 'flutter',
    Platform.isWindows ? ['/c', 'flutter', ...buildArgs] : buildArgs,
    mode: ProcessStartMode.inheritStdio,
    workingDirectory: Directory.current.path,
  );
  final code = await process.exitCode;
  if (code != 0) {
    stderr.writeln('Build failed with exit code $code');
    exit(code);
  }

  stdout.writeln('\nBuild succeeded. APKs in build/app/outputs/flutter-apk/');
}

File? _findAmapKeyFile() {
  for (final path in const ['Amap.csv', '../Amap.csv']) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

Future<String> _detectLocalApiBase() async {
  final ip = await _detectLocalIp();
  return 'http://$ip:8080';
}

Future<String> _detectLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        final a = addr.address;
        if (!addr.isLoopback &&
            (a.startsWith('192.168.') ||
                a.startsWith('10.') ||
                a.startsWith('172.'))) {
          return a;
        }
      }
    }
  } catch (_) {}
  return '127.0.0.1';
}

/// Extract the value of [name] from [args], supporting both
/// `--name value` and `--name=value` forms.
String? _optionValue(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == name && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$name=')) return args[i].substring(name.length + 1);
  }
  return null;
}

/// Remove custom flags *and their values* so they never leak to Flutter.
List<String> _filterCustomArgs(List<String> args, List<String> flagNames) {
  final result = <String>[];
  var skipNext = false;
  for (final arg in args) {
    if (skipNext) {
      skipNext = false;
      continue;
    }
    if (flagNames.contains(arg)) {
      skipNext = true;
      continue;
    }
    var matched = false;
    for (final flag in flagNames) {
      if (arg.startsWith('$flag=')) {
        matched = true;
        break;
      }
    }
    if (!matched) result.add(arg);
  }
  return result;
}
