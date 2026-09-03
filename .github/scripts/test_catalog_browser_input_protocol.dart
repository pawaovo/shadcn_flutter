// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../../packages/beautiful_ai_ui_catalog/integration_test/driver/catalog_browser_input_driver.dart';

/// This exercises the real HTTP boundary without launching a browser or GUI.
Future<void> main() async {
  final requests = <Map<String, Object?>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var failNext = false;
  server.listen((request) async {
    final bytes = await request.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final body = utf8.decode(bytes);
    requests.add(<String, Object?>{
      'method': request.method,
      'path': request.uri.path,
      'body': body.isEmpty ? null : jsonDecode(body),
      'raw_body': body,
      'body_bytes': bytes.length,
      'content_length': request.contentLength,
      'transfer_encoding': request.headers.value(
        HttpHeaders.transferEncodingHeader,
      ),
    });
    request.response.headers.contentType = ContentType.json;
    if (failNext) {
      failNext = false;
      request.response.statusCode = 500;
      request.response.write(
        '{"value":{"error":"timeout","message":"real upstream failure"}}',
      );
    } else {
      request.response.write('{"value":null}');
    }
    await request.response.close();
  });
  final driver = BrowserInputDriver(
    Uri.parse('http://127.0.0.1:${server.port}/session/actual/'),
  );
  void check(bool condition, String description) {
    if (!condition) throw StateError(description);
  }

  try {
    const navigation = <String, String>{
      'url': 'http://127.0.0.1/catalog?draft=中文🚀',
    };
    await driver.command('POST', 'url', navigation);
    final navigate = requests.single;
    final encodedNavigation = jsonEncode(navigation);
    final navigationBytes = utf8.encode(encodedNavigation).length;
    check(
      navigate['method'] == 'POST' && navigate['path'] == '/session/actual/url',
      'Navigation must send POST url to the existing session',
    );
    check(
      navigate['content_length'] == navigationBytes &&
          navigate['body_bytes'] == navigationBytes &&
          navigationBytes > encodedNavigation.length,
      'WebDriver must receive Content-Length measured in UTF-8 bytes',
    );
    check(
      navigate['transfer_encoding'] == null,
      'WebDriver requests must not use chunked transfer encoding',
    );
    check(
      navigate['raw_body'] == encodedNavigation &&
          (navigate['body'] as Map)['url'] == navigation['url'],
      'POST url must preserve its complete non-ASCII JSON body',
    );

    await driver.click(40, 80);
    final click = (requests.last['body'] as Map)['actions'] as List;
    check(
      click.single['type'] == 'pointer',
      'Clicks must use native W3C pointer actions',
    );
    check(
      click.single['actions'][0]['origin'] == 'viewport',
      'Coordinates must target the browser viewport',
    );
    check(
      click.single['actions'][1]['type'] == 'pointerDown',
      'Missing real pointer down',
    );
    check(
      click.single['actions'][2]['type'] == 'pointerUp',
      'Missing pointer release',
    );

    await driver.chord('\uE009', 'v');
    final keys =
        ((requests.last['body'] as Map)['actions'] as List).single['actions']
            as List;
    check(
      keys.map((key) => key['type']).join(',') == 'keyDown,keyDown,keyUp,keyUp',
      'Modifiers must be released',
    );
    check(
      keys.first['value'] == '\uE009' && keys.last['value'] == '\uE009',
      'Wrong modifier lifetime',
    );
    check(
      requests.last['path'] == '/session/actual/actions',
      'Commands must use the existing real session',
    );

    final before = requests.length;
    failNext = true;
    var failed = false;
    try {
      await driver.command('POST', 'window/rect', <String, int>{
        'width': 599,
        'height': 900,
      });
    } on StateError catch (error) {
      failed =
          error.message.contains('500') &&
          error.message.contains('real upstream failure');
    }
    check(failed, 'Upstream errors must fail acceptance unchanged');
    check(requests.length == before + 1, 'Failed operations must not retry');
    check(
      requests.every(
        (request) =>
            request['content_length'] == request['body_bytes'] &&
            request['transfer_encoding'] == null,
      ),
      'Every JSON command must retain explicit byte framing',
    );
    print(
      'Browser input protocol checks passed: UTF-8 byte framing, complete POST url, native events, balanced keys, existing session, original failure, no retry.',
    );
  } finally {
    driver.close();
    await server.close(force: true);
  }
}
