import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/widgets/study/stt_status_strip.dart';
import 'package:vocab_kr/services/speech/stt_race_status.dart';

const _labels = SttStatusLabels(
  engineName: _name,
  waiting: 'prêt',
  sending: 'envoi…',
  analyzing: 'analyse…',
  empty: 'rien compris',
  failed: 'échec',
  offline: 'Hors ligne',
  noEngine: 'Aucun moteur',
);

String _name(String id) =>
    const {'elevenlabs': 'ElevenLabs', 'whisper': 'Whisper'}[id] ?? id;

Future<void> _pump(WidgetTester tester, SttRaceStatus? status,
        {bool online = true}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SttStatusStrip(status: status, online: online, labels: _labels),
      ),
    ));

SttEngineStatus _e(String id, SttEngineState state,
        {bool cloud = false, String? text, bool matched = false}) =>
    SttEngineStatus(
        engineId: id,
        state: state,
        requiresNetwork: cloud,
        transcript: text,
        matched: matched);

void main() {
  testWidgets('nothing to show online without a status', (tester) async {
    await _pump(tester, null);
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('offline is always visible', (tester) async {
    await _pump(tester, null, online: false);
    expect(find.text('Hors ligne'), findsOneWidget);
  });

  testWidgets('cloud engines read "sending", on-device ones "analysing"',
      (tester) async {
    await _pump(
        tester,
        SttRaceStatus(phase: SttPhase.analyzing, engines: [
          _e('elevenlabs', SttEngineState.working, cloud: true),
          _e('whisper', SttEngineState.working),
        ]));
    expect(find.text('ElevenLabs · envoi…'), findsOneWidget);
    expect(find.text('Whisper · analyse…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
  });

  testWidgets('shows what each engine heard, right or wrong', (tester) async {
    await _pump(
        tester,
        SttRaceStatus(phase: SttPhase.done, engines: [
          _e('elevenlabs', SttEngineState.heard,
              cloud: true, text: '가다', matched: true),
          _e('whisper', SttEngineState.heard, text: '갔다'),
        ]));
    expect(find.text('ElevenLabs · « 가다 »'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Whisper · « 갔다 »'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('waiting, empty and failed engines are labelled', (tester) async {
    await _pump(
        tester,
        SttRaceStatus(phase: SttPhase.listening, engines: [
          _e('elevenlabs', SttEngineState.failed, cloud: true),
          _e('whisper', SttEngineState.empty),
          _e('system', SttEngineState.waiting),
        ]));
    expect(find.text('ElevenLabs · échec'), findsOneWidget);
    expect(find.text('Whisper · rien compris'), findsOneWidget);
    expect(find.text('system · prêt'), findsOneWidget);
  });

  testWidgets('a finished attempt without any engine says so', (tester) async {
    await _pump(tester, const SttRaceStatus(phase: SttPhase.done, engines: []),
        online: false);
    expect(find.text('Aucun moteur'), findsOneWidget);
    expect(find.text('Hors ligne'), findsOneWidget);
  });
}
