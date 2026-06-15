import 'package:flutter/material.dart';

import 'main.dart' show CityWalkTemplate, CityWalkStop, TravelSearchResult;
import 'scenic_spots_5a.dart'
    show
        FeaturedScenicSpot,
        all5AScenicSpots,
        featuredScenicSpots,
        featuredScenicTags;

class CollapsibleSection extends StatelessWidget {
  const CollapsibleSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [child],
      ),
    );
  }
}

class NearbyTripSpots extends StatelessWidget {
  const NearbyTripSpots({
    required this.city,
    required this.loading,
    required this.spots,
    required this.onAdd,
    required this.searchResultBuilder,
    super.key,
  });

  final String? city;
  final bool loading;
  final List<TravelSearchResult> spots;
  final ValueChanged<TravelSearchResult> onAdd;
  final Widget Function(TravelSearchResult result, VoidCallback onAdd) searchResultBuilder;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Near Your Next Trip',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (city != null)
                  Text(
                    city!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator()
          else
            Column(
              children: [
                for (final spot in spots) ...[
                  searchResultBuilder(spot, () => onAdd(spot)),
                  if (spot != spots.last)
                    const Divider(height: 1, indent: 12, endIndent: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class FeaturedScenicSection extends StatelessWidget {
  const FeaturedScenicSection({
    required this.selectedTag,
    required this.busy,
    required this.busyName,
    required this.onTagSelected,
    required this.onBrowseAll,
    required this.onSpotSelected,
    required this.scenicCardBuilder,
    super.key,
  });

  final String selectedTag;
  final bool busy;
  final String? busyName;
  final ValueChanged<String> onTagSelected;
  final VoidCallback onBrowseAll;
  final ValueChanged<FeaturedScenicSpot> onSpotSelected;
  final Widget Function(FeaturedScenicSpot spot, bool busy, VoidCallback onSelected) scenicCardBuilder;

  @override
  Widget build(BuildContext context) {
    final spots = featuredScenicSpots
        .where((spot) => spot.tags.contains(selectedTag))
        .toList(growable: false);
    final tagTotal = all5AScenicSpots
        .where((spot) => spot.tags.contains(selectedTag))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tag in featuredScenicTags) ...[
                SizedBox(
                  width: 85,
                  child: FilterChip(
                    key: ValueKey('scenic-tag-$tag'),
                    label: Text(tag),
                    selected: selectedTag == tag,
                    onSelected: (_) => onTagSelected(tag),
                    visualDensity: VisualDensity.comfortable,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final expanded = constraints.maxWidth >= 680;
            final children = [
              for (final spot in spots)
                scenicCardBuilder(
                  spot,
                  busy && busyName == spot.name,
                  () => onSpotSelected(spot),
                ),
            ];
            if (!expanded) {
              return Column(
                children: [
                  for (final child in children) ...[
                    child,
                    if (child != children.last) const SizedBox(height: 8),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final child in children)
                  SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: child,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('scenic-browse-all'),
            onPressed: busy ? null : () => onBrowseAll(),
            icon: const Icon(Icons.travel_explore_outlined),
            label: Text('Browse all $tagTotal "$selectedTag" 5A spots'),
          ),
        ),
      ],
    );
  }
}

class ScenicTagSheet extends StatelessWidget {
  const ScenicTagSheet({required this.tag, super.key});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = all5AScenicSpots
        .where((spot) => spot.tags.contains(tag))
        .toList(growable: false);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$tag · 5A Scenic Spots',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap a spot to search it and pick a day & time.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  _CompactLabel(text: '${spots.length}'),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                itemCount: spots.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 64, endIndent: 16),
                itemBuilder: (context, index) {
                  final spot = spots[index];
                  return ListTile(
                    key: ValueKey('scenic-sheet-${spot.name}'),
                    dense: true,
                    visualDensity: const VisualDensity(
                      horizontal: 0,
                      vertical: -1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        spot.icon,
                        size: 20,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${spot.city} · ${spot.summary}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton.filledTonal(
                      tooltip: 'Add scenic spot',
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context, spot),
                      icon: const Icon(Icons.add),
                    ),
                    onTap: () => Navigator.pop(context, spot),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeaturedScenicCard extends StatelessWidget {
  const FeaturedScenicCard({
    required this.spot,
    required this.busy,
    required this.onSelected,
    super.key,
  });

  final FeaturedScenicSpot spot;
  final bool busy;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  spot.icon,
                  color: scheme.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${spot.city} · ${spot.level} · ${spot.tags.join(" / ")}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spot.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 42,
                child: IconButton.filled(
                  key: ValueKey('featured-scenic-add-${spot.query}'),
                  tooltip: 'Add scenic spot',
                  onPressed: busy ? null : onSelected,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CityWalkTemplateCard extends StatelessWidget {
  const CityWalkTemplateCard({
    required this.template,
    required this.onCopy,
    required this.metricPillBuilder,
    required this.stopPreviewBuilder,
    super.key,
  });

  final CityWalkTemplate template;
  final VoidCallback onCopy;
  final Widget Function({required IconData icon, required String label, bool filled}) metricPillBuilder;
  final Widget Function({required int index, required CityWalkStop stop}) stopPreviewBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewStops = template.stops.take(3).toList(growable: false);
    return Card.filled(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
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
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_walk,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        template.summary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  key: ValueKey('copy-citywalk-${template.id}'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                metricPillBuilder(
                  icon: Icons.location_city_outlined,
                  label: template.city,
                  filled: true,
                ),
                metricPillBuilder(
                  icon: Icons.schedule_outlined,
                  label: template.duration,
                ),
                metricPillBuilder(
                  icon: Icons.route_outlined,
                  label: '${template.stops.length} stops',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < previewStops.length; index++) ...[
                  stopPreviewBuilder(index: index + 1, stop: previewStops[index]),
                  if (index != previewStops.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CityWalkStopPreview extends StatelessWidget {
  const CityWalkStopPreview({required this.index, required this.stop, super.key});

  final int index;
  final CityWalkStop stop;

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
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$index',
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
                stop.place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                '${stop.time} | ${stop.activity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactLabel extends StatelessWidget {
  const _CompactLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
