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
}
