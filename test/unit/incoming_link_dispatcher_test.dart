import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/incoming_link_dispatcher.dart';

void main() {
  final initial = Uri.parse('vocabkr://import?token=first');
  final warm = Uri.parse('vocabkr://import?token=second');

  for (final beforeLookup in [false, true]) {
    test(
      'initial API and stream replay dispatch once (early=$beforeLookup)',
      () async {
        final source = StreamController<Uri>(sync: true);
        addTearDown(source.close);
        final lookup = Completer<Uri?>();
        final received = <(Uri, bool)>[];
        final dispatcher = IncomingLinkDispatcher(
          getInitialLink: () => lookup.future,
          links: source.stream,
          onLink: (uri, cold) => received.add((uri, cold)),
        );
        addTearDown(dispatcher.dispose);
        if (beforeLookup) source.add(initial);
        lookup.complete(initial);
        await dispatcher.initialized;
        if (!beforeLookup) source.add(initial);
        source.add(warm);
        source.add(initial); // Later deliberate reopening remains a warm link.
        expect(received, [(initial, true), (warm, false), (initial, false)]);
      },
    );
  }

  test(
    'a distinct first stream URI is retained during initial lookup',
    () async {
      final source = StreamController<Uri>(sync: true);
      addTearDown(source.close);
      final lookup = Completer<Uri?>();
      final received = <(Uri, bool)>[];
      final dispatcher = IncomingLinkDispatcher(
        getInitialLink: () => lookup.future,
        links: source.stream,
        onLink: (uri, cold) => received.add((uri, cold)),
      );
      addTearDown(dispatcher.dispose);
      source.add(warm);
      lookup.complete(initial);
      await dispatcher.initialized;
      expect(received, [(initial, true), (warm, false)]);
    },
  );

  test(
    'disposing while initial lookup is pending drops all queued links',
    () async {
      final source = StreamController<Uri>(sync: true);
      addTearDown(source.close);
      final lookup = Completer<Uri?>();
      final received = <Uri>[];
      final dispatcher = IncomingLinkDispatcher(
        getInitialLink: () => lookup.future,
        links: source.stream,
        onLink: (uri, _) => received.add(uri),
      );
      source.add(initial);
      await dispatcher.dispose();
      lookup.complete(initial);
      await dispatcher.initialized;
      expect(received, isEmpty);
      expect(source.hasListener, isFalse);
    },
  );
}
