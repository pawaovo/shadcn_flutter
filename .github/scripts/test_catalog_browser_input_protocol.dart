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
    final body = await utf8.decoder.bind(request).join();
    requests.add(<String, Object?>{
      'method': request.method,
      'path': request.uri.path,
      'body': body.isEmpty ? null : jsonDecode(body),
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
    await driver.click(40, 80);
    final click = (requests.single['body'] as Map)['actions'] as List;
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
    print(
      'Browser input protocol checks passed: native events, balanced keys, existing session, original failure, no retry.',
    );
  } finally {
    driver.close();
    await server.close(force: true);
  }
}
