import 'dart:io';

import 'local_demo.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.write('''
Usage: dart run tool/build_ios.dart [options]

Options:
  --api-base <url>   Backend URL, default auto-detected LAN IP on port 8080.

Reads AMap keys from Amap.csv automatically.
Requires macOS with Xcode installed.
''');
    return;
  }

  if (!Platform.isMacOS) {
    stderr.writeln('iOS builds require macOS with Xcode.');
    exit(1);
  }

  final keyFile = _findAmapKeyFile();
  if (keyFile == null) {
    stderr.writeln('No Amap.csv found. Copy AmapExample.csv to Amap.csv and fill in your AMap keys.');
    exit(1);
  }

  final keys = parseAmapLocalKeys(keyFile.readAsStringSync());
  final apiBase = _optionValue(arguments, '--api-base') ?? await _detectLocalApiBase();

  final defines = <String, String>{
    'WAYFARE_API_BASE': apiBase,
    if (keys.webJsKey case final k?) 'AMAP_JS_KEY': k,
    if (keys.webJsSecurityCode case final k?) 'AMAP_JS_SECURITY_CODE': k,
    if (keys.androidKey case final k?) 'AMAP_ANDROID_KEY': k,
    if (keys.iosKey case final k?) 'AMAP_IOS_KEY': k,
  };

  stdout.writeln('Building iOS IPA with keys from $keyFile');
  for (final entry in defines.entries) {
    final masked = entry.value.length > 6
        ? '${entry.value.substring(0, 3)}***${entry.value.substring(entry.value.length - 3)}'
        : '***';
    stdout.writeln('  ${entry.key}=$masked');
  }

  final buildArgs = <String>[
    'build', 'ipa', '--release', '--no-pub',
    for (final entry in defines.entries)
      '--dart-define=${entry.key}=${entry.value}',
    ...arguments.where((a) => !a.startsWith('--api-base')),
  ];

  final process = await Process.start(
    'flutter',
    buildArgs,
    mode: ProcessStartMode.inheritStdio,
    workingDirectory: Directory.current.path,
  );
  final code = await process.exitCode;
  if (code != 0) {
    stderr.writeln('Build failed with exit code $code');
    exit(code);
  }

  stdout.writeln('\nBuild succeeded. IPAs in build/ios/ipa/');
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

String? _optionValue(List<String> arguments, String name) {
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == name && i + 1 < arguments.length) return arguments[i + 1];
    if (arguments[i].startsWith('$name=')) return arguments[i].substring(name.length + 1);
  }
  return null;
}
