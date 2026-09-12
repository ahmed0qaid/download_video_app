import 'package:background_downloader/background_downloader.dart';
import 'package:download_video_app/models.dart';
import 'package:download_video_app/services/download_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps direct task states to a unified transfer state', () {
    expect(
      DownloadManager.directState(TaskStatus.running).state,
      TransferState.running,
    );
    expect(DownloadManager.directState(TaskStatus.running).active, isTrue);
    expect(
      DownloadManager.directState(TaskStatus.complete).state,
      TransferState.completed,
    );
    expect(DownloadManager.directState(TaskStatus.complete).finalState, isTrue);
    expect(
      DownloadManager.directState(TaskStatus.failed).failure,
      isTrue,
    );
  });

  test('maps media job states to the same transfer state model', () {
    expect(
      DownloadManager.mediaState(MediaJobState.queued).state,
      TransferState.queued,
    );
    expect(DownloadManager.mediaState(MediaJobState.running).active, isTrue);
    expect(
      DownloadManager.mediaState(MediaJobState.succeeded).state,
      TransferState.completed,
    );
    expect(DownloadManager.mediaState(MediaJobState.canceled).failure, isTrue);
  });
}
