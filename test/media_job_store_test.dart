import 'package:download_video_app/models.dart';
import 'package:download_video_app/repositories/media_job_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late MediaJobStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    store = MediaJobStore(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() => store.close());

  test('persists media job history outside SharedPreferences', () async {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(123456789);
    final job = MediaJob(
      id: 'job-1',
      url: 'https://example.com/video',
      title: 'Example video',
      formatLabel: '1080p',
      formatSelector: 'bestvideo+bestaudio/best',
      createdAt: createdAt,
      state: MediaJobState.running,
      progress: 37,
      playlist: false,
      wifiOnly: true,
      useAria2: true,
      sizeBytes: 2048,
    );

    await store.upsert(job);
    final jobs = await store.loadAll();

    expect(jobs, hasLength(1));
    expect(jobs.single.id, 'job-1');
    expect(jobs.single.progress, 37);
    expect(jobs.single.createdAt, createdAt);
    expect(jobs.single.wifiOnly, isTrue);
    expect(jobs.single.sizeBytes, 2048);
  });

  test('updates and deletes media job history entries', () async {
    final job = MediaJob(
      id: 'job-2',
      url: 'https://example.com/audio',
      title: 'Example audio',
      formatLabel: 'MP3',
      formatSelector: 'bestaudio/best',
      audioFormat: 'mp3',
      createdAt: DateTime.fromMillisecondsSinceEpoch(987654321),
      state: MediaJobState.queued,
      progress: 0,
      playlist: false,
      wifiOnly: false,
      useAria2: false,
    );

    await store.upsert(job);
    await store.upsert(job.copyWith(state: MediaJobState.succeeded, progress: 100));

    expect((await store.loadAll()).single.state, MediaJobState.succeeded);

    await store.delete(job.id);
    expect(await store.loadAll(), isEmpty);
  });
}
