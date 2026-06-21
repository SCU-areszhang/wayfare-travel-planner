import 'package:flutter/material.dart';

import 'main.dart' show CityWalkTemplate, CityWalkStop, TravelSearchResult;
import 'scenic_spots_5a.dart'
    show
        FeaturedScenicSpot,
        all5AScenicSpots,
        featuredScenicSpots,
        featuredScenicTags;

class CollapsibleSection extends StatelessWidget {
  const CollapsibleSection({
    required this.title,
    required this.child,
    super.key,
  });

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
  final Widget Function(TravelSearchResult result, VoidCallback onAdd)
  searchResultBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Near Your Next Trip',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
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
        const SizedBox(height: 8),
        if (loading)
          const LinearProgressIndicator()
        else
          _ResponsiveCardWrap(
            minCardWidth: 280,
            children: [
              for (final spot in spots)
                searchResultBuilder(spot, () => onAdd(spot)),
            ],
          ),
      ],
    );
  }
}

class TravelImageFrame extends StatelessWidget {
  const TravelImageFrame({
    required this.imageUrl,
    required this.semanticLabel,
    this.fallbackIcon = Icons.image_outlined,
    this.aspectRatio = 3 / 2,
    super.key,
  });

  final String? imageUrl;
  final String semanticLabel;
  final IconData fallbackIcon;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final url = _displayableTravelImageUrl(imageUrl);
    final fallback = _TravelImageFallback(icon: fallbackIcon);
    final frame = Stack(
      fit: StackFit.expand,
      children: [
        if (url == null || url.isEmpty)
          fallback
        else
          Image.network(
            url,
            fit: BoxFit.cover,
            semanticLabel: semanticLabel,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  fallback,
                  const Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              );
            },
            errorBuilder: (context, error, stackTrace) => fallback,
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    if (aspectRatio == null) {
      return frame;
    }
    return AspectRatio(aspectRatio: aspectRatio!, child: frame);
  }
}

String? _displayableTravelImageUrl(String? value) {
  final url = value?.trim();
  if (url == null || url.isEmpty) {
    return null;
  }
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host == 'picsum.photos' || host.endsWith('.picsum.photos')) {
    return null;
  }
  return url;
}

class _TravelImageFallback extends StatelessWidget {
  const _TravelImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.tertiaryContainer.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, color: scheme.onPrimaryContainer, size: 36),
      ),
    );
  }
}

class _ResponsiveCardWrap extends StatelessWidget {
  const _ResponsiveCardWrap({required this.children, this.minCardWidth = 280});

  final List<Widget> children;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final maxWidth = constraints.maxWidth;
        final rawColumnCount = (maxWidth / (minCardWidth + spacing)).floor();
        final columnCount = maxWidth < minCardWidth * 2 + spacing
            ? 1
            : rawColumnCount.clamp(2, 3).toInt();
        final cardWidth = columnCount == 1
            ? maxWidth
            : (maxWidth - spacing * (columnCount - 1)) / columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
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
  final Widget Function(
    FeaturedScenicSpot spot,
    bool busy,
    VoidCallback onSelected,
  )
  scenicCardBuilder;

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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('scenic-browse-all'),
            onPressed: busy ? null : () => onBrowseAll(),
            icon: const Icon(Icons.travel_explore_outlined),
            label: Text('Browse all $tagTotal "$selectedTag" 5A spots'),
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
              return _ResponsiveCardWrap(children: children);
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final child in children)
                  SizedBox(width: (constraints.maxWidth - 8) / 2, child: child),
              ],
            );
          },
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
    required this.imageUrl,
    required this.busy,
    required this.onSelected,
    super.key,
  });

  final FeaturedScenicSpot spot;
  final String? imageUrl;
  final bool busy;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: busy ? null : onSelected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: TravelImageFrame(
                imageUrl: imageUrl,
                semanticLabel: spot.name,
                fallbackIcon: spot.icon,
                aspectRatio: null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton.filled(
                      key: ValueKey('featured-scenic-add-${spot.query}'),
                      tooltip: 'Add scenic spot',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onPressed: busy ? null : onSelected,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CityWalkTemplateCard extends StatelessWidget {
  const CityWalkTemplateCard({
    required this.template,
    required this.imageUrl,
    required this.onCopy,
    required this.metricPillBuilder,
    required this.stopPreviewBuilder,
    super.key,
  });

  final CityWalkTemplate template;
  final String? imageUrl;
  final VoidCallback onCopy;
  final Widget Function({
    required IconData icon,
    required String label,
    bool filled,
  })
  metricPillBuilder;
  final Widget Function({required int index, required CityWalkStop stop})
  stopPreviewBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewStops = template.stops.take(3).toList(growable: false);
    return Card.filled(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: TravelImageFrame(
              imageUrl: imageUrl,
              semanticLabel: template.title,
              fallbackIcon: Icons.directions_walk,
              aspectRatio: null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 28,
                      child: IconButton.filled(
                        key: ValueKey('copy-citywalk-${template.id}'),
                        onPressed: onCopy,
                        iconSize: 15,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy CityWalk',
                        icon: const Icon(Icons.content_copy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  template.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
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
                const SizedBox(height: 8),
                for (
                  var index = 0;
                  index < previewStops.length;
                  index++
                ) ...[
                  stopPreviewBuilder(
                    index: index + 1,
                    stop: previewStops[index],
                  ),
                  if (index != previewStops.length - 1)
                    const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CityWalkStopPreview extends StatelessWidget {
  const CityWalkStopPreview({
    required this.index,
    required this.stop,
    super.key,
  });

  final int index;
  final CityWalkStop stop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${stop.time} | ${stop.activity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
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
