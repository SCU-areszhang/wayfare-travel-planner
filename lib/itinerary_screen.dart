part of 'package:wayfare_travel_planner/main.dart';

class _ItineraryScreen extends StatelessWidget {
  const _ItineraryScreen({
    required this.title,
    required this.days,
    required this.onSearch,
    required this.onAddDay,
    required this.onDeleteDay,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onReorder,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  final String title;
  final List<ItineraryDay> days;
  final Future<List<TravelSearchResult>> Function(String query) onSearch;
  final VoidCallback onAddDay;
  final ValueChanged<ItineraryDay> onDeleteDay;
  final ValueChanged<ItineraryItem> onEdit;
  final ValueChanged<ItineraryItem> onMove;
  final ValueChanged<ItineraryItem> onDelete;
  final void Function(ItineraryDay day, int oldIndex, int newIndex) onReorder;
  final void Function(ItineraryDay day, ItineraryItem item) onDuplicate;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stopCount = days.fold<int>(0, (sum, day) => sum + day.items.length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        Card.filled(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.route_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${days.length} dates \u00b7 $stopCount stops \u00b7 current itinerary',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 400;
                    if (compact) {
                      return Row(
                        children: [
                          IconButton.outlined(
                            tooltip: 'Open map',
                            onPressed: onOpenMap,
                            icon: const Icon(Icons.map_outlined),
                          ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onOpenMap,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Open Map'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (days.isEmpty) ...[
          const SizedBox(height: 16),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No itinerary days yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a day first, then add attractions or activities.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onAddDay,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Day'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...[
          _ItineraryDayRouteCard(
            key: ValueKey(days[dayIndex].id),
            day: days[dayIndex],
            dayIndex: dayIndex,
            onSearch: onSearch,
            onDeleteDay: () => onDeleteDay(days[dayIndex]),
            onEdit: onEdit,
            onMove: onMove,
            onDelete: onDelete,
            onReorder: onReorder,
            onDuplicate: onDuplicate,
            onOpenMap: onOpenMap,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ItineraryDayRouteCard extends StatelessWidget {
  const _ItineraryDayRouteCard({
    super.key,
    required this.day,
    required this.dayIndex,
    required this.onSearch,
    required this.onDeleteDay,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onReorder,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  final ItineraryDay day;
  final int dayIndex;
  final Future<List<TravelSearchResult>> Function(String query) onSearch;
  final VoidCallback onDeleteDay;
  final ValueChanged<ItineraryItem> onEdit;
  final ValueChanged<ItineraryItem> onMove;
  final ValueChanged<ItineraryItem> onDelete;
  final void Function(ItineraryDay day, int oldIndex, int newIndex) onReorder;
  final void Function(ItineraryDay day, ItineraryItem item) onDuplicate;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usePrimary = dayIndex.isEven;
    final container = usePrimary
        ? scheme.primaryContainer
        : scheme.secondaryContainer;
    final onContainer = usePrimary
        ? scheme.onPrimaryContainer
        : scheme.onSecondaryContainer;
    return Card.filled(
      color: container.withValues(alpha: 0.34),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: container,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_month_outlined,
                    color: onContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.date,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (day.reminder.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          day.reminder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CompactLabel(text: _stopCountLabel(day.items.length)),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Delete date',
                  onPressed: onDeleteDay,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  icon: Icons.location_city_outlined,
                  label: day.city.trim().isEmpty ? 'None' : day.city,
                  filled: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 8),
            if (day.items.isEmpty)
              _ItineraryEmptyStopPreview(onOpenMap: onOpenMap)
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: day.items.length,
                // onReorderItem only exists on Flutter >=3.42, and this project
                // must still build on 3.41 stable. Stay on the deprecated
                // onReorder, which reports newIndex before the dragged item is
                // removed and therefore needs the classic adjustment.
                // ignore: deprecated_member_use
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  onReorder(day, oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final item = day.items[index];
                  return Padding(
                    key: ValueKey(item.id),
                    padding: EdgeInsets.only(
                      bottom: index == day.items.length - 1 ? 0 : 8,
                    ),
                    child: _ItineraryItemCard(
                      item: item,
                      index: index,
                      onSearch: onSearch,
                      onEdit: () => onEdit(item),
                      onMove: () => onMove(item),
                      onDelete: () => onDelete(item),
                      onDuplicate: () => onDuplicate(day, item),
                      onOpenMap: onOpenMap,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ItineraryEmptyStopPreview extends StatelessWidget {
  const _ItineraryEmptyStopPreview({required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(Icons.add, size: 16, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'No stops yet. Add a place from search or pick a point on the map.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        TextButton.icon(
          onPressed: onOpenMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Map'),
        ),
      ],
    );
  }
}

enum _ItemAction { move, duplicate, delete }

class _ItineraryItemCard extends StatefulWidget {
  const _ItineraryItemCard({
    required this.item,
    required this.index,
    required this.onSearch,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  final ItineraryItem item;
  final int index;
  final Future<List<TravelSearchResult>> Function(String query) onSearch;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenMap;

  @override
  State<_ItineraryItemCard> createState() => _ItineraryItemCardState();
}

class _ItineraryItemCardState extends State<_ItineraryItemCard> {
  String? _imageUrl;
  String? _imageLoadKey;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _ItineraryItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.place != widget.item.place ||
        oldWidget.item.city != widget.item.city) {
      _imageUrl = null;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final query = _itineraryItemImageQuery(widget.item);
    if (query.isEmpty) {
      return;
    }
    final loadKey = '${widget.item.id}:$query';
    if (_imageLoadKey == loadKey) {
      return;
    }
    _imageLoadKey = loadKey;
    String? imageUrl;
    try {
      final results = await widget.onSearch(query);
      TravelSearchResult? bestResult;
      var bestScore = -1000;
      for (final result in results) {
        if (_isUsableTravelImageUrl(result.imageUrl)) {
          final score = _travelImageResultScore(result, query);
          if (bestResult == null || score > bestScore) {
            bestResult = result;
            bestScore = score;
          }
        }
      }
      imageUrl = bestResult?.imageUrl?.trim();
    } catch (_) {
      imageUrl = null;
    }
    if (!mounted || _imageLoadKey != loadKey) {
      return;
    }
    setState(() => _imageUrl = imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: TravelImageFrame(
              imageUrl: _imageUrl,
              semanticLabel: widget.item.place,
              fallbackIcon: Icons.place_outlined,
              aspectRatio: null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.index + 1}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Text(
                    '${widget.item.time} | ${widget.item.activity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (widget.item.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      widget.item.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Open map',
                      onPressed: widget.onOpenMap,
                      icon: const Icon(Icons.map_outlined),
                      visualDensity: VisualDensity.compact,
                    ),
                    PopupMenuButton<_ItemAction>(
                      tooltip: 'More actions',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (action) {
                        switch (action) {
                          case _ItemAction.move:
                            widget.onMove();
                          case _ItemAction.duplicate:
                            widget.onDuplicate();
                          case _ItemAction.delete:
                            widget.onDelete();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _ItemAction.move,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.drive_file_move_outlined,
                            ),
                            title: Text('Move to date'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ItemAction.duplicate,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.copy_outlined),
                            title: Text('Duplicate'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ItemAction.delete,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Tooltip(
                      message: 'Drag to move within this date',
                      child: ReorderableDragStartListener(
                        index: widget.index,
                        child: SizedBox.square(
                          dimension: 36,
                          child: Icon(
                            Icons.drag_indicator,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _itineraryItemImageQuery(ItineraryItem item) {
  final place = item.place.trim();
  if (place.isEmpty) {
    return '';
  }
  final city = item.city.trim();
  if (city.isEmpty || place.contains(city)) {
    return place;
  }
  return '$city $place';
}
