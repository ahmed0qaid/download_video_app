import 'package:download_video_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips media jobs through map serialization', () {
    final job = MediaJob(
      id: 'abc',
      url: 'https://example.com/watch?v=1',
      title: 'A title',
      formatLabel: 'Audio MP3',
      formatSelector: 'bestaudio/best',
      audioFormat: 'mp3',
      thumbnail: 'https://example.com/thumb.jpg',
      createdAt: DateTime.fromMillisecondsSinceEpoch(42),
      state: MediaJobState.failed,
      progress: 91,
      etaSeconds: 4,
      outputPath: '/tmp/file.mp3',
      error: 'network',
      sizeBytes: 10,
      playlist: true,
      wifiOnly: true,
      useAria2: false,
    );

    final restored = MediaJob.fromMap(job.toMap());

    expect(restored.id, job.id);
    expect(restored.audioFormat, 'mp3');
    expect(restored.state, MediaJobState.failed);
    expect(restored.playlist, isTrue);
    expect(restored.useAria2, isFalse);
  });

  test('labels media formats without requiring platform services', () {
    final video = MediaFormat.fromMap({
      'id': '18',
      'ext': 'mp4',
      'height': 720,
      'fps': 60,
      'vcodec': 'h264',
      'acodec': 'aac',
    });

    expect(video.isCombined, isTrue);
    expect(video.qualityLabel, contains('720p'));
    expect(video.qualityLabel, contains('mp4'));
  });
}
