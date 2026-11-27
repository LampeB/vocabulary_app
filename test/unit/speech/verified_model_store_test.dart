import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponderin_whisper/src/verified_model_store.dart';

void main() {
  late Directory directory;
  late HttpServer server;
  late File destination;
  late Uri source;
  late List<int> payload;
  var requests = 0;
  var status = HttpStatus.ok;
  final model = utf8.encode('fixture model');
  final checksum = sha256.convert(model).toString();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ponderin-model-test-');
    destination = File('${directory.path}/model.bin');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    source = Uri.parse('http://127.0.0.1:${server.port}/model');
    payload = model;
    requests = 0;
    status = HttpStatus.ok;
    server.listen((request) async {
      requests++;
      request.response.statusCode = status;
      request.response.add(payload);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  Future<File> download() => VerifiedModelStore().ensure(
    destination: destination,
    source: source,
    checksum: checksum,
    expectedBytes: model.length,
  );

  test(
    'concurrent preparations share one download and reuse verified cache',
    () async {
      await Future.wait([download(), download()]);
      expect(requests, 1);
      expect(await destination.readAsBytes(), model);
      expect(await File('${destination.path}.part').exists(), isFalse);

      await download();
      expect(requests, 1);
    },
  );

  test(
    'checksum failure preserves the installed file and can be retried',
    () async {
      final oldModel = utf8.encode('old file');
      await destination.writeAsBytes(oldModel);
      payload = List.filled(model.length, 0);

      await expectLater(download(), throwsStateError);
      expect(await destination.readAsBytes(), oldModel);
      expect(await File('${destination.path}.part').exists(), isFalse);

      payload = model;
      await download();
      expect(requests, 2);
      expect(await destination.readAsBytes(), model);
    },
  );

  test(
    'oversized response is rejected without installing a partial model',
    () async {
      payload = List.filled(model.length + 1, 0);
      await expectLater(download(), throwsStateError);
      expect(await destination.exists(), isFalse);
      expect(await File('${destination.path}.part').exists(), isFalse);
    },
  );

  test('failed HTTP request can be retried', () async {
    status = HttpStatus.serviceUnavailable;
    await expectLater(download(), throwsA(isA<HttpException>()));
    expect(await destination.exists(), isFalse);

    status = HttpStatus.ok;
    await download();
    expect(requests, 2);
  });
}
