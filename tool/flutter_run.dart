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

  final device = await _detectWebDevice();
  if (device == null) {
    stderr.writeln('No web device found. Install Chrome or Edge.');
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

  final runArgs = [
    'run',
    '-d',
    device,
    '--dart-define-from-file=${defineFile.path}',
    ...arguments,
  ];

  stdout.writeln('Starting flutter run with AMap keys from $keyFile');

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

  final code = await process.exitCode;
  tempDir.deleteSync(recursive: true);
  exit(code);
}

Future<String?> _detectWebDevice() async {
  final process = await Process.start(
    Platform.isWindows ? 'cmd.exe' : 'flutter',
    Platform.isWindows ? ['/c', 'flutter', 'devices', '--machine'] : ['devices', '--machine'],
    mode: ProcessStartMode.normal,
    workingDirectory: Directory.current.path,
  );
  final output = await process.stdout.transform(utf8.decoder).join();
  await process.exitCode;

  final devices = jsonDecode(output) as List;
  for (final d in devices) {
    final platform = d['targetPlatform'] as String? ?? '';
    if (platform.startsWith('web-')) {
      return d['id'] as String;
    }
  }
  return null;
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
