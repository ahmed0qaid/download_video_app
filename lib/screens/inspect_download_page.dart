import 'package:flutter/material.dart';

import '../models.dart';
import '../services/download_manager.dart';
import '../widgets/shared.dart';

class InspectDownloadPage extends StatefulWidget {
  const InspectDownloadPage({
    super.key,
    required this.manager,
    required this.sourceUrl,
  });

  final DownloadManager manager;
  final String sourceUrl;

  @override
  State<InspectDownloadPage> createState() => _InspectDownloadPageState();
}

class _InspectDownloadPageState extends State<InspectDownloadPage> {
  LinkInspection? _inspection;
  String? _error;
  bool _loading = true;
  bool _starting = false;
  late bool _wifiOnly;
  bool _downloadPlaylist = false;
  String? _choiceKey;

  @override
  void initState() {
    super.initState();
    _wifiOnly = widget.manager.wifiOnly;
    _inspect();
  }

  Future<void> _inspect() async {
    setState(() {
      _loading = true;
      _error = null;
      _inspection = null;
    });
    try {
      final inspection = await widget.manager.inspectLink(widget.sourceUrl);
      if (!mounted) return;
      setState(() {
        _inspection = inspection;
        _downloadPlaylist = inspection.media?.isPlaylist ?? false;
        _choiceKey = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startDirect(RemoteFileInfo info) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await widget.manager.startDownload(info, wifiOnly: _wifiOnly);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${info.fileName} added to the download queue.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showError('Could not start download: $error');
      setState(() => _starting = false);
    }
  }

  Future<void> _startMedia(MediaInfo info) async {
    if (_starting) return;
    final choices = _mediaChoices(info);
    if (choices.isEmpty) {
      _showError('No downloadable formats were reported for this link.');
      return;
    }
    final selectedKey = _choiceKey ?? choices.first.key;
    final selected = choices.firstWhere((e) => e.key == selectedKey);
    setState(() => _starting = true);
    try {
      await widget.manager.startMediaDownload(
        info,
        formatSelector: selected.selector,
        formatLabel: selected.label,
        audioFormat: selected.audioFormat,
        playlist: info.isPlaylist && _downloadPlaylist,
        wifiOnly: _wifiOnly,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            info.isPlaylist && _downloadPlaylist
                ? 'Playlist added to the media queue.'
                : '${info.title} added to the media queue.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showError('Could not start media download: $error');
      setState(() => _starting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<_MediaChoice> _mediaChoices(MediaInfo info) {
    final choices = <_MediaChoice>[];
    final preferred = widget.manager.preferredQuality;

    if (preferred > 0) {
      choices.add(
        _MediaChoice(
          key: 'preferred',
          label: 'Recommended • up to ${preferred}p',
          subtitle: 'Best video and audio, merged when needed',
          selector:
              'bestvideo[height<=$preferred]+bestaudio/best[height<=$preferred]',
        ),
      );
    } else {
      choices.add(const _MediaChoice(
        key: 'preferred',
        label: 'Recommended • best available',
        subtitle: 'Best video and audio, merged when needed',
        selector: 'bestvideo+bestaudio/best',
      ));
    }

    choices.add(const _MediaChoice(
      key: 'best',
      label: 'Best available video',
      subtitle: 'Highest quality reported by the source',
      selector: 'bestvideo+bestaudio/best',
    ));

    for (final height in const [2160, 1440, 1080, 720, 480, 360]) {
      if (height == preferred) continue;
      choices.add(
        _MediaChoice(
          key: 'quality:$height',
          label: '${height}p or lower',
          subtitle: 'Prefer a video stream at or below ${height}p',
          selector:
              'bestvideo[height<=$height]+bestaudio/best[height<=$height]',
        ),
      );
    }

    final combined = info.formats.where((e) => e.isCombined).toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    final seen = <String>{};
    for (final format in combined) {
      final signature = '${format.height}:${format.ext}:${format.fps}';
      if (!seen.add(signature) || choices.length >= 14) continue;
      choices.add(
        _MediaChoice(
          key: 'format:${format.id}',
          label: 'Single stream • ${format.qualityLabel}',
          subtitle: format.sizeBytes == null
              ? 'Video + audio in one source stream'
              : '${DownloadManager.formatBytes(format.sizeBytes)} • video + audio',
          selector: format.id,
        ),
      );
    }

    choices.addAll(const [
      _MediaChoice(
        key: 'audio:mp3',
        label: 'Audio • MP3',
        subtitle: 'Extract audio and convert with FFmpeg',
        selector: 'bestaudio/best',
        audioFormat: 'mp3',
      ),
      _MediaChoice(
        key: 'audio:m4a',
        label: 'Audio • M4A',
        subtitle: 'Extract the best audio track',
        selector: 'bestaudio/best',
        audioFormat: 'm4a',
      ),
    ]);
    return choices;
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;
    return Scaffold(
      appBar: AppBar(title: const Text('Inspect Download')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (_loading)
              const _LoadingCard()
            else if (_error != null)
              _ErrorCard(error: _error!, onRetry: _inspect)
            else if (inspection?.direct != null)
              _buildDirect(context, inspection!.direct!)
            else if (inspection?.media != null)
              _buildMedia(context, inspection!.media!),
          ],
        ),
      ),
    );
  }

  Widget _buildDirect(BuildContext context, RemoteFileInfo info) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleRow(
                  icon: Icons.insert_drive_file_outlined,
                  title: info.fileName,
                  subtitle: info.host,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _InfoBox(
                        label: 'Size',
                        value: DownloadManager.formatBytes(info.sizeBytes),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoBox(
                        label: 'Type',
                        value: info.mimeType ?? 'Unknown',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SectionLabel('Direct transfer'),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wi-Fi only'),
                  subtitle: const Text('Do not start this transfer on cellular data'),
                  value: _wifiOnly,
                  onChanged: (value) => setState(() => _wifiOnly = value),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _starting ? null : () => _startDirect(info),
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(_starting ? 'Adding…' : 'Start Direct Download'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _RightsNotice(),
      ],
    );
  }

  Widget _buildMedia(BuildContext context, MediaInfo info) {
    final choices = _mediaChoices(info);
    final currentKey = choices.any((e) => e.key == _choiceKey)
        ? _choiceKey!
        : choices.first.key;
    final selected = choices.firstWhere((e) => e.key == currentKey);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.thumbnail != null && info.thumbnail!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        info.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _MediaPlaceholder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _TitleRow(
                  icon: info.isPlaylist
                      ? Icons.playlist_play_rounded
                      : Icons.smart_display_outlined,
                  title: info.title,
                  subtitle: [
                    if (info.uploader?.isNotEmpty == true) info.uploader!,
                    info.extractor,
                  ].join(' • '),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _InfoBox(
                        label: info.isPlaylist ? 'Items' : 'Duration',
                        value: info.isPlaylist
                            ? '${info.entries.length}'
                            : DownloadManager.formatMediaDuration(info.durationSeconds),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoBox(
                        label: 'Formats',
                        value: info.isPlaylist ? 'Per item' : '${info.formats.length}',
                      ),
                    ),
                  ],
                ),
                if (info.isPlaylist) ...[
                  const SizedBox(height: 16),
                  const SectionLabel('Playlist'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Download the full playlist'),
                    subtitle: Text('${info.entries.length} detected entries'),
                    value: _downloadPlaylist,
                    onChanged: (value) => setState(() => _downloadPlaylist = value),
                  ),
                  if (info.entries.isNotEmpty)
                    ...info.entries.take(4).map(
                          (entry) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.play_arrow_rounded),
                            title: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: entry.durationSeconds == null
                                ? null
                                : Text(
                                    DownloadManager.formatMediaDuration(
                                      entry.durationSeconds,
                                    ),
                                  ),
                          ),
                        ),
                ],
                const SizedBox(height: 16),
                const SectionLabel('Quality & format'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: currentKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.high_quality_rounded),
                  ),
                  items: choices
                      .map(
                        (choice) => DropdownMenuItem(
                          value: choice.key,
                          child: Text(
                            choice.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _choiceKey = value),
                ),
                const SizedBox(height: 7),
                Text(
                  selected.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wi-Fi only'),
                  subtitle: Text(
                    widget.manager.useAria2
                        ? 'Background WorkManager job • Aria2 acceleration enabled'
                        : 'Background WorkManager job • standard yt-dlp transfer',
                  ),
                  value: _wifiOnly,
                  onChanged: (value) => setState(() => _wifiOnly = value),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _starting ? null : () => _startMedia(info),
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _starting
                          ? 'Adding…'
                          : selected.audioFormat == null
                              ? 'Download Video'
                              : 'Download Audio',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _RightsNotice(),
      ],
    );
  }
}

class _MediaChoice {
  const _MediaChoice({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.selector,
    this.audioFormat,
  });

  final String key;
  final String label;
  final String subtitle;
  final String selector;
  final String? audioFormat;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Inspecting link and available media formats…'),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text('Link inspection failed', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 7),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
        Icon(Icons.verified_outlined, color: Theme.of(context).colorScheme.primary),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
      child: Center(
        child: Icon(
          Icons.smart_display_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _RightsNotice extends StatelessWidget {
  const _RightsNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.security_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Download only media you are allowed to save. The app does not implement DRM circumvention, paywall bypassing, or private-account cookie extraction.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
