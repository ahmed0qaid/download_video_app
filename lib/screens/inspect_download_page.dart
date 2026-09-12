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
  RemoteFileInfo? _info;
  String? _error;
  bool _loading = true;
  bool _starting = false;
  late bool _wifiOnly;

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
    });
    try {
      final info = await widget.manager.inspectUrl(widget.sourceUrl);
      if (!mounted) return;
      setState(() => _info = info);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startDownload() async {
    final info = _info;
    if (info == null || _starting) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start download: $error')),
      );
      setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspect Download'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Checking server metadata…'),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Card(
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
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _inspect,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (info != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: .1),
                            child: Icon(
                              Icons.insert_drive_file_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.fileName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  info.host,
                                  style: Theme.of(context).textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.verified_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
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
                      const SectionLabel('Destination'),
                      const SizedBox(height: 7),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder_open_rounded),
                        title: const Text('App support storage'),
                        subtitle: Text(widget.manager.downloadDirectory),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Wi-Fi only'),
                        subtitle: const Text('Do not start this transfer on cellular data'),
                        value: _wifiOnly,
                        onChanged: (value) => setState(() => _wifiOnly = value),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.layers_rounded),
                        title: const Text('Queue settings'),
                        subtitle: Text(
                          '${widget.manager.simultaneousDownloads} simultaneous • '
                          '${widget.manager.autoRetry ? 'up to 5 retries' : 'no automatic retries'}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _starting ? null : _startDownload,
                          icon: _starting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(_starting ? 'Adding…' : 'Start Download'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This app accepts direct HTTP/HTTPS file URLs only. It does not bypass DRM or website access restrictions.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
