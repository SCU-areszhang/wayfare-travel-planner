import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/release_readiness.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('wayfare_readiness_');
    _writeFixture(root);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test('local mode passes with warnings when release secrets are absent', () {
    final report = evaluateReleaseReadiness(
      root: root,
      mode: ReadinessMode.local,
      environment: const <String, String>{},
    );

    expect(report.passed, isTrue);
    expect(
      report.issues.where(
        (issue) => issue.severity == ReadinessSeverity.warning,
      ),
      isNotEmpty,
    );
  });

  test('release mode fails when production inputs are absent', () {
    final report = evaluateReleaseReadiness(
      root: root,
      mode: ReadinessMode.release,
      environment: const <String, String>{},
    );

    expect(report.passed, isFalse);
    expect(
      report.issues.map((issue) => issue.id),
      containsAll(<String>[
        'env-WAYFARE_AUTH_SECRET',
        'env-WAYFARE_ALLOWED_ORIGINS',
        'env-WAYFARE_API_BASE',
        'env-AMAP_JS_KEY',
        'env-AMAP_JS_SECURITY_CODE',
        'env-AMAP_ANDROID_KEY',
        'android-signing-inputs',
      ]),
    );
  });

  test('release mode passes when production inputs are complete', () {
    final report = evaluateReleaseReadiness(
      root: root,
      mode: ReadinessMode.release,
      environment: const <String, String>{
        'WAYFARE_AUTH_SECRET': '0123456789abcdef0123456789abcdef',
        'WAYFARE_ALLOWED_ORIGINS': 'https://app.wayfare-travel.com',
        'WAYFARE_API_BASE': 'https://api.wayfare-travel.com',
        'AMAP_JS_KEY': 'amap-js-key',
        'AMAP_JS_SECURITY_CODE': 'amap-js-security-code',
        'AMAP_ANDROID_KEY': 'amap-android-key',
        'WAYFARE_ANDROID_KEYSTORE': '/secure/wayfare-release.jks',
        'WAYFARE_ANDROID_STORE_PASSWORD': 'store-password',
        'WAYFARE_ANDROID_KEY_ALIAS': 'wayfare',
        'WAYFARE_ANDROID_KEY_PASSWORD': 'key-password',
      },
    );

    expect(report.passed, isTrue);
    expect(report.issues, isEmpty);
  });
}

void _writeFixture(Directory root) {
  _write(root, 'AGENTS.md', '8 roles');
  _write(root, 'README.md', 'readme');
  _write(root, 'backend/README.md', 'backend');
  _write(root, 'pubspec.lock', 'packages:');
  _write(root, 'backend/pubspec.lock', 'packages:');
  _write(root, 'lib/main.dart', '''
const apiBase = String.fromEnvironment('WAYFARE_API_BASE');
const amapJsKey = String.fromEnvironment('AMAP_JS_KEY');
const amapAndroidKey = String.fromEnvironment('AMAP_ANDROID_KEY');
''');
  _write(root, 'backend/bin/server.dart', '''
const env = 'WAYFARE_AUTH_SECRET WAYFARE_ALLOWED_ORIGINS';
const sessions = 'sessions';
const rateLimit = 'WAYFARE_RATE_LIMIT_AUTH_PER_WINDOW';
class RateLimiter {}
void revokeSession() {}
void _validateCreateItinerary() {}
void _validateCreateSavedItem() {}
String _sessionTokenHash(String token) => token;
''');
  _write(root, '.github/workflows/ci.yml', '''
steps:
  - run: flutter analyze
  - run: flutter test
  - run: dart test
  - run: dart run tool/release_readiness.dart --mode local
''');
  _write(root, 'android/app/build.gradle', '''
id "org.jetbrains.kotlin.android"
def releaseStoreFile = System.getenv("WAYFARE_ANDROID_KEYSTORE")
def keyPropertiesFile = rootProject.file("key.properties")
sourceCompatibility JavaVersion.VERSION_17
targetCompatibility JavaVersion.VERSION_17
jvmTarget = "17"
android { signingConfigs { release {} } }
''');
  _write(root, 'android/app/build.gradle.kts', '''
val releaseStoreFilePath =
    providers.environmentVariable("WAYFARE_ANDROID_KEYSTORE").orNull
val keyPropertiesFile = rootProject.file("key.properties")
android { signingConfigs { create("release") {} } }
''');
}

void _write(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
