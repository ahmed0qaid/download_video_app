import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/shared.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int _category = 0;
  bool _selectMode = false;
  final _search = TextEditingController();

  final _items = const [
    LibraryItem(name: 'lecture-09-servo-gate.pdf', size: '18.4 MB', meta: 'mit.edu • 10:42 AM', type: 'PDF'),
    LibraryItem(name: 'telemetry_dump_2026-03.csv', size: '4.2 MB', meta: 'internal.analytics • 08:15 AM', type: 'CSV'),
    LibraryItem(name: 'blender-4.2.0-linux.tar.xz', size: '340 MB', meta: 'SHA256 • Yesterday', type: 'TAR'),
    LibraryItem(name: 'ambient_soundscape_hq.flac', size: '68.1 MB', meta: '24-bit / 96kHz • May 24', type: 'FLAC'),
    LibraryItem(name: 'contract-signed-draft.docx', size: '1.8 MB', meta: 'Legal Vault • May 18', type: 'DOCX'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.tealDark : AppColors.teal;
    final query = _search.text.toLowerCase();
    final filtered = _items.where((e) => e.name.toLowerCase().contains(query)).toList();

    return SafeArea(
      child: Column(
        children: [
          const TransferHeader(subtitle: 'Library'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Library', style: Theme.of(context).textTheme.headlineMedium),
                          Text('142 items archived locally', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _selectMode = !_selectMode),
                      icon: const Icon(Icons.checklist_rounded, size: 18),
                      label: Text(_selectMode ? 'Done' : 'Select'),
                    ),
                    const SizedBox(width: 6),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.tune_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('79.8 GB', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(width: 6),
                            Text('of 128 GB stored', style: Theme.of(context).textTheme.labelMedium),
                            const Spacer(),
                            Text('62% CAPACITY', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: accent)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 7,
                            value: .62,
                            backgroundColor: dark ? AppColors.nightLine : AppColors.softFill,
                            valueColor: AlwaysStoppedAnimation(accent),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _StorageLegend('Docs 35.1G'),
                            _StorageLegend('Video 20.7G'),
                            _StorageLegend('Audio 14.4G'),
                            _StorageLegend('Other 9.6G'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search downloaded files…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in const [
                        (0, 'All'),
                        (1, 'Documents'),
                        (2, 'Media'),
                        (3, 'Archives'),
                        (4, 'Installers'),
                      ]) ...[
                        Pill(
                          label: entry.$2,
                          selected: _category == entry.$1,
                          onTap: () => setState(() => _category = entry.$1),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Today'),
                const SizedBox(height: 8),
                ...filtered.take(2).map((item) => _LibraryRow(item: item, selectMode: _selectMode)),
                const SizedBox(height: 12),
                const SectionLabel('This Week'),
                const SizedBox(height: 8),
                ...filtered.skip(2).take(2).map((item) => _LibraryRow(item: item, selectMode: _selectMode)),
                const SizedBox(height: 12),
                const SectionLabel('Earlier'),
                const SizedBox(height: 8),
                ...filtered.skip(4).map((item) => _LibraryRow(item: item, selectMode: _selectMode)),
              ],
            ),
          ),
          if (_selectMode)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: dark ? AppColors.nightSurface : AppColors.surface,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  Text('0 selected', style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  TextButton.icon(onPressed: () {}, icon: const Icon(Icons.share_rounded), label: const Text('Share')),
                  TextButton.icon(onPressed: () {}, icon: const Icon(Icons.drive_file_move_rounded), label: const Text('Move')),
                  TextButton.icon(onPressed: () {}, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Delete')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StorageLegend extends StatelessWidget {
  const _StorageLegend(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 10));
  }
}

class _LibraryRow extends StatefulWidget {
  const _LibraryRow({required this.item, required this.selectMode});

  final LibraryItem item;
  final bool selectMode;

  @override
  State<_LibraryRow> createState() => _LibraryRowState();
}

class _LibraryRowState extends State<_LibraryRow> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final icon = switch (widget.item.type) {
      'PDF' => Icons.picture_as_pdf_outlined,
      'CSV' => Icons.table_chart_outlined,
      'TAR' => Icons.folder_zip_outlined,
      'FLAC' => Icons.graphic_eq_rounded,
      _ => Icons.description_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          leading: widget.selectMode
              ? Checkbox(value: selected, onChanged: (v) => setState(() => selected = v ?? false))
              : Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
          title: Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${widget.item.size} • ${widget.item.meta}'),
          trailing: widget.selectMode
              ? null
              : widget.item.type == 'PDF'
                  ? OutlinedButton(onPressed: () {}, child: const Text('Open'))
                  : const Icon(Icons.more_vert_rounded),
        ),
      ),
    );
  }
}
