import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/local_demo.dart';

void main() {
  test('parses AMap local key file without including trailing fields', () {
    final keys = parseAmapLocalKeys('''
Wayfare_WebSvc api_key:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Wayfare_WebJS api_key:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb extra-field
Security_code:cccccccccccccccccccccccccccccccc
''');

    expect(keys.webServiceKey, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    expect(keys.webJsKey, 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
    expect(keys.webJsSecurityCode, 'cccccccccccccccccccccccccccccccc');
  });

  test('CLI and environment style keys override parsed file keys', () {
    final fileKeys = parseAmapLocalKeys('''
Wayfare_WebSvc api_key:file-service
Wayfare_WebJS api_key:file-js
Security_code:file-security
''');
    final merged = fileKeys.merge(const AmapLocalKeys(
      webServiceKey: 'override-service',
      webJsSecurityCode: 'override-security',
    ));

    expect(merged.webServiceKey, 'override-service');
    expect(merged.webJsKey, 'file-js');
    expect(merged.webJsSecurityCode, 'override-security');
  });

  test('verifies backend AMap search when live POI rows are returned',
      () async {
    final server = await _searchServer({
      'items': [
        {'id': 'amap-1', 'type': 'amap_poi', 'name': 'West Lake'},
      ],
    });
    try {
      final verified = await verifyAmapBackendSearch(
        apiBase: Uri.parse('http://${server.address.address}:${server.port}'),
        timeout: const Duration(seconds: 5),
      );
      expect(verified, isTrue);
    } finally {
      await server.close(force: true);
    }
  });

  test('rejects backend AMap search without live POI rows', () async {
    final server = await _searchServer({
      'items': [
        {'id': 'seed-1', 'type': 'scenic_spot', 'name': 'Seed Spot'},
      ],
    });
    try {
      final verified = await verifyAmapBackendSearch(
        apiBase: Uri.parse('http://${server.address.address}:${server.port}'),
        timeout: const Duration(seconds: 5),
      );
      expect(verified, isFalse);
    } finally {
      await server.close(force: true);
    }
  });
}

Future<HttpServer> _searchServer(Map<String, Object?> responseBody) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    if (request.method == 'GET' && request.uri.path == '/search') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(responseBody))
        ..close();
      return;
    }
    request.response
      ..statusCode = HttpStatus.notFound
      ..close();
  });
  return server;
}
