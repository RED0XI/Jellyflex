import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/download_notify.dart';
import 'package:jellyflex/core/downloads.dart';

DownloadEntry _entry(String id, DownloadStatus status, {int received = 0, int total = 0}) => DownloadEntry(
  itemId: id,
  serverUrl: 'https://jf.example',
  userId: 'u',
  name: 'Film $id',
  type: 'Movie',
  folder: r'C:\x',
  status: status,
  received: received,
  total: total,
  mediaFile: status == DownloadStatus.done ? r'C:\x\media.mkv' : null,
);

void main() {
  test('Nur gerade fertig gewordene Downloads melden', () {
    final before = [
      _entry('a', DownloadStatus.downloading),
      _entry('b', DownloadStatus.done),
      _entry('c', DownloadStatus.queued),
    ];
    final after = [
      _entry('a', DownloadStatus.done),
      _entry('b', DownloadStatus.done),
      _entry('c', DownloadStatus.downloading),
      _entry('d', DownloadStatus.done), // neu hinzugekommen (z. B. beim Start geladen) – keine Meldung
    ];
    expect(finishedDownloads(before, after).map((e) => e.itemId), ['a']);
  });

  test('Fortschritt für die Taskleiste', () {
    expect(runningProgress([_entry('a', DownloadStatus.queued)]), isNull);
    expect(runningProgress([_entry('a', DownloadStatus.downloading, received: 25, total: 100)]), 0.25);
    expect(runningProgress([_entry('a', DownloadStatus.downloading)]), 0);
  });
}
