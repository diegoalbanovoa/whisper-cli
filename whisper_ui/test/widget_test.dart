import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_ui/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const WhisperApp());
    expect(find.text('Whisper Transcriber'), findsOneWidget);
  });
}
