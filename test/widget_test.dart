import 'package:download_video_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows primary download manager navigation', (tester) async {
    await tester.pumpWidget(const DownloadVideoApp());

    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('No downloads yet'), findsOneWidget);
  });
}
