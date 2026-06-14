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

  final defines = <String, String>{};
  if (keys.webJsKey case final k?) {
    defines['AMAP_JS_KEY'] = k;
  }
  if (keys.webJsSecurityCode case final k?) {
    defines['AMAP_JS_SECURITY_CODE'] = k;
  }
  if (keys.androidKey case final k?) {
    defines['AMAP_ANDROID_KEY'] = k;
  }
  if (keys.iosKey case final k?) {
    defines['AMAP_IOS_KEY'] = k;
  }

  final apiBase =
      _optionValue(arguments, '--api-base') ?? 'http://127.0.0.1:8080';
  defines['WAYFARE_API_BASE'] = apiBase;

  final buildArgs = <String>[
    'build',
    'apk',
    '--release',
    '--split-per-abi',
    '--no-pub',
    for (final entry in defines.entries)
      '--dart-define=${entry.key}=${entry.value}',
    ...arguments.where((a) => !a.startsWith('--api-base')),
  ];

  stdout.writeln('Building APK with keys from $keyFile');
  for (final entry in defines.entries) {
    final masked = entry.value.length > 6
        ? '${entry.value.substring(0, 3)}***${entry.value.substring(entry.value.length - 3)}'
        : '***';
    stdout.writeln('  ${entry.key}=$masked');
  }

  final process = await Process.start(
    Platform.isWindows ? 'cmd.exe' : 'flutter',
    Platform.isWindows ? ['/c', 'flutter', ...buildArgs] : buildArgs,
    mode: ProcessStartMode.inheritStdio,
    workingDirectory: Directory.current.path,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln('Build failed with exit code $exitCode');
    exit(exitCode);
  }

  stdout.writeln('\nBuild succeeded. APKs in build/app/outputs/flutter-apk/');
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

String? _optionValue(List<String> arguments, String name) {
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == name && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
    if (arguments[i].startsWith('$name=')) {
      return arguments[i].substring(name.length + 1);
    }
  }
  return null;
}
