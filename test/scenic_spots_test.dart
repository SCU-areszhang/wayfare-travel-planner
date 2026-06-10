import 'package:flutter_test/flutter_test.dart';
import 'package:wayfare_travel_planner/scenic_spots_5a.dart';

void main() {
  test('built-in 5A library is large, unique, and well-formed', () {
    expect(all5AScenicSpots.length, greaterThanOrEqualTo(250));

    final names = all5AScenicSpots.map((spot) => spot.name).toSet();
    expect(names.length, all5AScenicSpots.length,
        reason: 'spot names must be unique');

    for (final spot in all5AScenicSpots) {
      expect(spot.level, '5A');
      expect(spot.name.trim(), isNotEmpty);
      expect(spot.city.trim(), isNotEmpty);
      expect(spot.summary.trim(), isNotEmpty);
      expect(spot.query.trim(), isNotEmpty);
      expect(spot.tags, isNotEmpty, reason: '${spot.name} needs tags');
      for (final tag in spot.tags) {
        expect(featuredScenicTags, contains(tag),
            reason: '${spot.name} uses unknown tag $tag');
      }
    }
  });

  test('every browse tag matches at least ten spots', () {
    for (final tag in featuredScenicTags) {
      final count =
          all5AScenicSpots.where((spot) => spot.tags.contains(tag)).length;
      expect(count, greaterThanOrEqualTo(10), reason: 'tag $tag too small');
    }
  });

  test('curated featured subset comes from the full library', () {
    expect(featuredScenicSpots, isNotEmpty);
    for (final spot in featuredScenicSpots) {
      expect(all5AScenicSpots, contains(spot));
    }
  });
}
