import 'dart:io';

enum ReadinessMode { local, release }

enum ReadinessSeverity { warning, error }

class ReadinessIssue {
  const ReadinessIssue({
    required this.id,
    required this.severity,
    required this.message,
    required this.fix,
  });

  final String id;
  final ReadinessSeverity severity;
  final String message;
  final String fix;
}

class ReleaseReadinessReport {
  const ReleaseReadinessReport({
    required this.mode,
    required this.issues,
  });

  final ReadinessMode mode;
  final List<ReadinessIssue> issues;

  bool get passed =>
      issues.every((issue) => issue.severity != ReadinessSeverity.error);

  String render() {
    final buffer = StringBuffer()
      ..writeln('Wayfare release readiness: ${mode.name}')
      ..writeln(passed ? 'status: pass' : 'status: fail');
    if (issues.isEmpty) {
      buffer.writeln('issues: none');
      return buffer.toString();
    }

    buffer.writeln('issues:');
    for (final issue in issues) {
      buffer
        ..writeln('- [${issue.severity.name}] ${issue.id}: ${issue.message}')
        ..writeln('  fix: ${issue.fix}');
    }
    return buffer.toString();
  }
}

ReleaseReadinessReport evaluateReleaseReadiness({
  required Directory root,
  required ReadinessMode mode,
  required Map<String, String> environment,
}) {
  final issues = <ReadinessIssue>[];
  final checker = _ReadinessChecker(root, mode, environment, issues);
  checker
    ..checkRequiredFiles()
    ..checkStaticSecurityAndReleaseWiring()
    ..checkReleaseEnvironment();
  return ReleaseReadinessReport(mode: mode, issues: List.unmodifiable(issues));
}

void main(List<String> arguments) {
  final mode = _parseMode(arguments);
  final rootPath = _optionValue(arguments, '--root') ?? Directory.current.path;
  final report = evaluateReleaseReadiness(
    root: Directory(rootPath),
    mode: mode,
    environment: Platform.environment,
  );
  stdout.write(report.render());
  if (!report.passed) {
    exitCode = 1;
  }
}

ReadinessMode _parseMode(List<String> arguments) {
  final value = _optionValue(arguments, '--mode') ?? 'local';
  return switch (value) {
    'local' => ReadinessMode.local,
    'release' => ReadinessMode.release,
    _ => throw ArgumentError.value(value, '--mode', 'Use local or release.'),
  };
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

class _ReadinessChecker {
  _ReadinessChecker(this.root, this.mode, this.environment, this.issues);

  final Directory root;
  final ReadinessMode mode;
  final Map<String, String> environment;
  final List<ReadinessIssue> issues;

  void checkRequiredFiles() {
    const requiredFiles = <String, String>{
      'AGENTS.md': 'Keep the 8-role SOP available for future changes.',
      'README.md': 'Document setup, backend, AMap, and release commands.',
      'backend/README.md': 'Document backend API and production settings.',
      '.github/workflows/ci.yml': 'Keep repeatable CI verification in git.',
      'pubspec.lock': 'Pin Flutter dependency resolution for release builds.',
      'backend/pubspec.lock': 'Pin backend dependency resolution.',
      'lib/main.dart': 'Keep the Flutter entrypoint present.',
      'backend/bin/server.dart': 'Keep the backend entrypoint present.',
    };
    requiredFiles.forEach((path, fix) {
      if (!_file(path).existsSync()) {
        _addError('missing-$path', 'Required file $path is missing.', fix);
      }
    });
  }

  void checkStaticSecurityAndReleaseWiring() {
    _requireContains(
      'backend/bin/server.dart',
      const [
        'WAYFARE_AUTH_SECRET',
        'WAYFARE_ALLOWED_ORIGINS',
        'sessions',
        'revokeSession',
        '_sessionTokenHash',
        'RateLimiter',
        'WAYFARE_RATE_LIMIT_AUTH_PER_WINDOW',
      ],
      'backend-session-hardening',
      'Backend must keep configurable auth, CORS, revocable sessions, and rate limiting wired.',
      'Restore the auth/session/CORS/rate-limit hardening before publishing.',
    );
    _requireContains(
      'lib/main.dart',
      const ['WAYFARE_API_BASE', 'AMAP_JS_KEY', 'AMAP_ANDROID_KEY'],
      'frontend-release-defines',
      'Flutter release builds must keep API and AMap dart-defines wired.',
      'Restore the API base and AMap dart-define configuration.',
    );
    _requireContains(
      '.github/workflows/ci.yml',
      const [
        'flutter analyze',
        'flutter test',
        'dart test',
        'release_readiness'
      ],
      'ci-release-gates',
      'CI must include analysis, tests, and the readiness gate.',
      'Add the release readiness command back to CI.',
    );
    _checkAndroidSigningFile('android/app/build.gradle');
    _checkAndroidSigningFile('android/app/build.gradle.kts');
  }

  void checkReleaseEnvironment() {
    final releaseOnlySeverity = mode == ReadinessMode.release
        ? ReadinessSeverity.error
        : ReadinessSeverity.warning;
    _expectStrongSecret(
      'WAYFARE_AUTH_SECRET',
      releaseOnlySeverity,
      'Use a unique random value with at least 32 characters.',
    );
    _expectHttpsList(
      'WAYFARE_ALLOWED_ORIGINS',
      releaseOnlySeverity,
      'Set a comma-separated list of production HTTPS origins only.',
    );
    _expectHttpsUrl(
      'WAYFARE_API_BASE',
      releaseOnlySeverity,
      'Build the app with the production HTTPS backend base URL.',
    );
    _expectPresent(
      'AMAP_JS_KEY',
      releaseOnlySeverity,
      'Set the AMap Web JS key through --dart-define or CI variables.',
    );
    _expectPresent(
      'AMAP_JS_SECURITY_CODE',
      releaseOnlySeverity,
      'Set the AMap Web JS security code through --dart-define or CI variables.',
    );
    _expectPresent(
      'AMAP_ANDROID_KEY',
      releaseOnlySeverity,
      'Set the AMap Android key for com.idm.travelplanner.',
    );
    _expectAndroidSigning(releaseOnlySeverity);
  }

  void _checkAndroidSigningFile(String path) {
    final file = _file(path);
    if (!file.existsSync()) {
      return;
    }
    final content = file.readAsStringSync();
    if (content.contains('signingConfigs.getByName("debug")') ||
        content.contains("signingConfigs.getByName('debug')") ||
        content.contains('signingConfigs.debug')) {
      _addError(
        'android-debug-release-signing-$path',
        'Android release build still references the debug signing config.',
        'Use a release signing config backed by env vars or android/key.properties.',
      );
    }
    if (!content.contains('WAYFARE_ANDROID_KEYSTORE') ||
        !content.contains('key.properties')) {
      _addError(
        'android-release-signing-$path',
        'Android release signing is not wired to env vars or key.properties.',
        'Wire release signing without committing keystores or passwords.',
      );
    }
    final needsKotlinConfig = path.endsWith('build.gradle');
    if (needsKotlinConfig &&
        (!content.contains('org.jetbrains.kotlin.android') ||
            !content.contains('sourceCompatibility JavaVersion.VERSION_17') ||
            !content.contains('targetCompatibility JavaVersion.VERSION_17') ||
            !content.contains('jvmTarget = "17"'))) {
      _addError(
        'android-jvm-targets-$path',
        'Android Java and Kotlin JVM targets are not consistently set to 17.',
        'Apply the Kotlin Android plugin and keep compileOptions/kotlinOptions on JVM 17.',
      );
    }
  }

  void _expectAndroidSigning(ReadinessSeverity severity) {
    final envComplete = _hasValue('WAYFARE_ANDROID_KEYSTORE') &&
        _hasValue('WAYFARE_ANDROID_STORE_PASSWORD') &&
        _hasValue('WAYFARE_ANDROID_KEY_ALIAS') &&
        _hasValue('WAYFARE_ANDROID_KEY_PASSWORD');
    final keyProperties = _file('android/key.properties');
    final keyPropertiesComplete =
        keyProperties.existsSync() && _keyPropertiesComplete(keyProperties);
    if (envComplete || keyPropertiesComplete) {
      return;
    }
    _add(
      severity,
      'android-signing-inputs',
      'Android release signing credentials are not available.',
      'Set WAYFARE_ANDROID_KEYSTORE, WAYFARE_ANDROID_STORE_PASSWORD, '
          'WAYFARE_ANDROID_KEY_ALIAS, and WAYFARE_ANDROID_KEY_PASSWORD, or '
          'create ignored android/key.properties with storeFile, storePassword, '
          'keyAlias, and keyPassword.',
    );
  }

  bool _keyPropertiesComplete(File file) {
    final content = file.readAsStringSync();
    return const [
      'storeFile',
      'storePassword',
      'keyAlias',
      'keyPassword'
    ].every((key) => RegExp('^$key\\s*=', multiLine: true).hasMatch(content));
  }

  void _expectStrongSecret(
    String name,
    ReadinessSeverity severity,
    String fix,
  ) {
    final value = environment[name]?.trim() ?? '';
    if (value.length >= 32 && !_looksPlaceholder(value)) {
      return;
    }
    _add(severity, 'env-$name', '$name is missing or too weak.', fix);
  }

  void _expectHttpsList(
    String name,
    ReadinessSeverity severity,
    String fix,
  ) {
    final value = environment[name]?.trim() ?? '';
    final origins = value
        .split(',')
        .map((origin) => origin.trim())
        .where((origin) => origin.isNotEmpty)
        .toList();
    if (origins.isNotEmpty && origins.every(_isProductionHttpsUrl)) {
      return;
    }
    _add(severity, 'env-$name', '$name must contain production HTTPS origins.',
        fix);
  }

  void _expectHttpsUrl(
    String name,
    ReadinessSeverity severity,
    String fix,
  ) {
    final value = environment[name]?.trim() ?? '';
    if (_isProductionHttpsUrl(value)) {
      return;
    }
    _add(severity, 'env-$name', '$name must be a production HTTPS URL.', fix);
  }

  void _expectPresent(
    String name,
    ReadinessSeverity severity,
    String fix,
  ) {
    final value = environment[name]?.trim() ?? '';
    if (value.isNotEmpty && !_looksPlaceholder(value)) {
      return;
    }
    _add(severity, 'env-$name', '$name is missing or placeholder-like.', fix);
  }

  bool _isProductionHttpsUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }
    const blockedHosts = {
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
      '::1',
    };
    return !blockedHosts.contains(uri.host) && !_looksPlaceholder(uri.host);
  }

  bool _looksPlaceholder(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('replace') ||
        normalized.contains('example') ||
        normalized.contains('placeholder') ||
        normalized.contains('your_') ||
        normalized == 'secret' ||
        normalized == 'development' ||
        normalized.startsWith('ci-');
  }

  bool _hasValue(String name) {
    final value = environment[name]?.trim() ?? '';
    return value.isNotEmpty && !_looksPlaceholder(value);
  }

  void _requireContains(
    String path,
    List<String> needles,
    String id,
    String message,
    String fix,
  ) {
    final file = _file(path);
    if (!file.existsSync()) {
      return;
    }
    final content = file.readAsStringSync();
    final missing =
        needles.where((needle) => !content.contains(needle)).toList();
    if (missing.isNotEmpty) {
      _addError(id, '$message Missing: ${missing.join(', ')}.', fix);
    }
  }

  File _file(String path) => File('${root.path}/$path');

  void _addError(String id, String message, String fix) {
    _add(ReadinessSeverity.error, id, message, fix);
  }

  void _add(ReadinessSeverity severity, String id, String message, String fix) {
    issues.add(
      ReadinessIssue(
        id: id,
        severity: severity,
        message: message,
        fix: fix,
      ),
    );
  }
}
