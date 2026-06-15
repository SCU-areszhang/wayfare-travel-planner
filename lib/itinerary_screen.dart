part of 'package:wayfare_travel_planner/main.dart';

class _ItineraryScreen extends StatelessWidget {
  const _ItineraryScreen({
    required this.title,
    required this.days,
    required this.onAddDay,
    required this.onDeleteDay,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  final String title;
  final List<ItineraryDay> days;
  final VoidCallback onAddDay;
  final ValueChanged<ItineraryDay> onDeleteDay;
  final ValueChanged<ItineraryItem> onEdit;
  final ValueChanged<ItineraryItem> onMove;
  final ValueChanged<ItineraryItem> onDelete;
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
            day: days[dayIndex],
            dayIndex: dayIndex,
            onDeleteDay: () => onDeleteDay(days[dayIndex]),
            onEdit: onEdit,
            onMove: onMove,
            onDelete: onDelete,
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
    required this.day,
    required this.dayIndex,
    required this.onDeleteDay,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  final ItineraryDay day;
  final int dayIndex;
  final VoidCallback onDeleteDay;
  final ValueChanged<ItineraryItem> onEdit;
  final ValueChanged<ItineraryItem> onMove;
  final ValueChanged<ItineraryItem> onDelete;
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
              Column(
                children: [
                  for (var index = 0; index < day.items.length; index++)
                    Padding(
                      key: ValueKey(day.items[index].id),
                      padding: EdgeInsets.only(
                        bottom: index == day.items.length - 1 ? 0 : 8,
                      ),
                      child: _ItineraryItemCard(
                        item: day.items[index],
                        index: index,
                        onEdit: () => onEdit(day.items[index]),
                        onMove: () => onMove(day.items[index]),
                        onDelete: () => onDelete(day.items[index]),
                        onDuplicate: () => onDuplicate(day, day.items[index]),
                        onOpenMap: onOpenMap,
                      ),
                    ),
                ],
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

class _ItineraryItemCard extends StatelessWidget {
  const _ItineraryItemCard({
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  final ItineraryItem item;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${index + 1}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.time} | ${item.activity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (item.note.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Open map',
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.map_outlined),
                    visualDensity: VisualDensity.compact,
                  ),
                  PopupMenuButton<_ItemAction>(
                    tooltip: 'More actions',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      switch (action) {
                        case _ItemAction.move:
                          onMove();
                        case _ItemAction.duplicate:
                          onDuplicate();
                        case _ItemAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ItemAction.move,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.drive_file_move_outlined),
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
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
