import 'package:download_video_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders main transfer screen', (tester) async {
    await tester.pumpWidget(const DownloadVideoApp());
    expect(find.text('Transfers'), findsWidgets);
    expect(find.text('DIRECT STREAM INGEST'), findsOneWidget);
  });
}
