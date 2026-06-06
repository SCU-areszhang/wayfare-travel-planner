import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

int _localIdCounter = 0;

String _nextLocalId(String prefix) {
  _localIdCounter += 1;
  return '$prefix-$_localIdCounter';
}

void main() {
  runApp(const WayfareApp());
}

enum AppTab { home, explore, itinerary, saved, profile }

enum ThemeSource {
  system('System Dynamic Color', Color(0xFF386A8B)),
  ocean('Ocean Blue', Color(0xFF0B6B8A)),
  forest('Forest Green', Color(0xFF2E6F40)),
  sunrise('Sunrise Orange', Color(0xFFB65D21)),
  neutral('Neutral Gray', Color(0xFF5F6368)),
  custom('Custom Accent Color', Color(0xFF386A8B));

  const ThemeSource(this.label, this.seed);

  final String label;
  final Color seed;
}

class Destination {
  const Destination({
    required this.name,
    required this.theme,
    required this.duration,
    required this.reason,
    required this.summary,
    required this.tone,
    required this.priority,
  });

  final String name;
  final String theme;
  final String duration;
  final String reason;
  final String summary;
  final Color tone;
  final bool priority;
}

class ItineraryDay {
  ItineraryDay({
    required this.title,
    required this.date,
    required this.city,
    required this.reminder,
    required this.items,
  });

  String title;
  String date;
  String city;
  String reminder;
  final List<ItineraryItem> items;
}

class ItineraryItem {
  ItineraryItem({
    String? id,
    required this.time,
    required this.place,
    required this.activity,
    required this.note,
    required this.status,
  }) : id = id ?? _nextLocalId('item');

  final String id;
  String time;
  String place;
  String activity;
  String note;
  String status;
}

class MapPlace {
  const MapPlace({
    required this.name,
    required this.category,
    required this.distance,
    required this.description,
    required this.rating,
    required this.point,
    required this.icon,
  });

  final String name;
  final String category;
  final String distance;
  final String description;
  final String rating;
  final LatLng point;
  final IconData icon;
}

class SavedTrip {
  const SavedTrip({
    required this.destination,
    required this.dateRange,
    required this.itemCount,
    required this.lastUpdated,
    required this.folder,
    required this.upcoming,
  });

  final String destination;
  final String dateRange;
  final String itemCount;
  final String lastUpdated;
  final String folder;
  final bool upcoming;
}

class MockTravelRepository {
  final destinations = const [
    Destination(
      name: 'Hangzhou Lakeside',
      theme: 'Nature + Culture',
      duration: '2 days',
      reason: 'matches your nature preference',
      summary:
          'A calm weekend around West Lake, tea fields, evening streets, and easy walks.',
      tone: Color(0xFF4E8A7E),
      priority: true,
    ),
    Destination(
      name: 'Shanghai City Break',
      theme: 'City Break',
      duration: '1-2 days',
      reason: 'good for short trips',
      summary:
          'Museums, skyline viewpoints, food streets, and compact metro-friendly routes.',
      tone: Color(0xFF4E6A96),
      priority: true,
    ),
    Destination(
      name: 'Suzhou Garden Trail',
      theme: 'Culture',
      duration: '2 days',
      reason: 'saved by culture travelers',
      summary:
          'Classical gardens, canals, soft evening routes, and quiet photography spots.',
      tone: Color(0xFF7A7D4E),
      priority: false,
    ),
    Destination(
      name: 'Chengdu Food Weekend',
      theme: 'Food',
      duration: '3 days',
      reason: 'matches your foodie tag',
      summary: 'Street snacks, teahouses, parks, and a relaxed itinerary pace.',
      tone: Color(0xFFAA6046),
      priority: false,
    ),
  ];

  final itineraryDays = [
    ItineraryDay(
      title: 'Day 1',
      date: 'May 24',
      city: 'Hangzhou',
      reminder: 'Light rain possible, keep outdoor stops flexible',
      items: [
        ItineraryItem(
          time: '09:00',
          place: 'West Lake',
          activity: 'Walk the lakeside route',
          note: 'Start near Broken Bridge and keep the morning gentle.',
          status: 'Saved',
        ),
        ItineraryItem(
          time: '12:30',
          place: 'Hefang Street',
          activity: 'Lunch and snack stops',
          note: 'Try local noodles, then keep 30 minutes for souvenirs.',
          status: 'Saved',
        ),
        ItineraryItem(
          time: '16:00',
          place: 'Longjing Village',
          activity: 'Tea field visit',
          note: 'Move here if rain stops; otherwise switch with museum.',
          status: 'Unsaved changes',
        ),
      ],
    ),
    ItineraryDay(
      title: 'Day 2',
      date: 'May 25',
      city: 'Hangzhou',
      reminder: 'Reminder: review route before departure',
      items: [
        ItineraryItem(
          time: '10:00',
          place: 'China National Tea Museum',
          activity: 'Indoor culture stop',
          note: 'Good fallback for unstable weather.',
          status: 'Saved',
        ),
        ItineraryItem(
          time: '14:30',
          place: 'Xixi Wetland',
          activity: 'Nature walk',
          note: 'Open map first to check attraction distribution.',
          status: 'Saved',
        ),
      ],
    ),
  ];

  final mapPlaces = const [
    MapPlace(
      name: 'West Lake',
      category: 'Attraction',
      distance: '1.2 km',
      description: 'Scenic lakeside area for the first morning route.',
      rating: '4.8 placeholder',
      point: LatLng(30.2431, 120.1508),
      icon: Icons.place_outlined,
    ),
    MapPlace(
      name: 'Hefang Street',
      category: 'Food',
      distance: '2.0 km',
      description: 'Dense snack street and short shopping stop.',
      rating: '4.5 placeholder',
      point: LatLng(30.2416, 120.1784),
      icon: Icons.restaurant_outlined,
    ),
    MapPlace(
      name: 'Longjing Village',
      category: 'Nature',
      distance: '7.8 km',
      description: 'Tea fields, quiet paths, and photography viewpoints.',
      rating: '4.7 placeholder',
      point: LatLng(30.2207, 120.0912),
      icon: Icons.park_outlined,
    ),
    MapPlace(
      name: 'Metro Station',
      category: 'Transport',
      distance: '0.4 km',
      description: 'Useful transfer point for the planned route.',
      rating: 'Route context',
      point: LatLng(30.2607, 120.1606),
      icon: Icons.directions_transit_outlined,
    ),
    MapPlace(
      name: 'Saved Cafe',
      category: 'Saved Place',
      distance: '1.7 km',
      description: 'A manually saved place for a flexible rest break.',
      rating: 'Saved',
      point: LatLng(30.2524, 120.1422),
      icon: Icons.bookmark_border,
    ),
  ];

  final savedTrips = const [
    SavedTrip(
      destination: 'Hangzhou Lakeside',
      dateRange: 'May 24 - May 25',
      itemCount: '5 planned items',
      lastUpdated: 'Updated today',
      folder: 'Weekend',
      upcoming: true,
    ),
    SavedTrip(
      destination: 'Shanghai City Break',
      dateRange: 'Jun 7 - Jun 8',
      itemCount: '4 planned items',
      lastUpdated: 'Updated yesterday',
      folder: 'City Break',
      upcoming: true,
    ),
    SavedTrip(
      destination: 'Suzhou Garden Trail',
      dateRange: 'Mar 12 - Mar 13',
      itemCount: '7 past items',
      lastUpdated: 'Archived',
      folder: 'Culture',
      upcoming: false,
    ),
    SavedTrip(
      destination: 'Chengdu Food Weekend',
      dateRange: 'Jan 18 - Jan 20',
      itemCount: '9 past items',
      lastUpdated: 'Archived',
      folder: 'Food',
      upcoming: false,
    ),
  ];

  final filters = const [
    'Weekend Trip',
    'City Break',
    'Nature',
    'Food',
    'Culture',
    'Family',
    'Budget Friendly',
  ];

  final preferences = const [
    'Adventure',
    'Relaxation',
    'Foodie',
    'Culture',
    'Nature',
    'Shopping',
    'Family',
    'Photography',
  ];

  final guideCards = const [
    'Pre-trip checklist: destination, dates, attractions, packing, route check',
    'First itinerary tip: add at least one place or activity before saving',
    'Map first use: tap markers to keep location context in a bottom sheet',
    'Offline note: keep manual notes for booking details until backend services exist',
  ];

  final supportFaqs = const [
    'Login: use phone verification or social auth when backend auth is ready.',
    'Search: try city, attraction, or theme keywords. Empty states are handled in the UI.',
    'Itinerary editing: add, edit, delete, move, and save plan items from the timeline.',
    'Map loading: retry is shown if location data fails instead of a blank map.',
    'Privacy: saved trips and preference data remain grouped under Profile settings.',
  ];
}

class WayfareApp extends StatefulWidget {
  const WayfareApp({super.key});

  @override
  State<WayfareApp> createState() => _WayfareAppState();
}

class _WayfareAppState extends State<WayfareApp> {
  ThemeSource _themeSource = ThemeSource.system;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final fallbackLight = ColorScheme.fromSeed(
          seedColor: _themeSource.seed,
          brightness: Brightness.light,
        );
        final fallbackDark = ColorScheme.fromSeed(
          seedColor: _themeSource.seed,
          brightness: Brightness.dark,
        );

        final useDynamic = _themeSource == ThemeSource.system;
        final lightScheme = useDynamic && lightDynamic != null
            ? lightDynamic.harmonized()
            : fallbackLight;
        final darkScheme = useDynamic && darkDynamic != null
            ? darkDynamic.harmonized()
            : fallbackDark;

        return MaterialApp(
          title: 'Wayfare',
          debugShowCheckedModeBanner: false,
          theme: _themeData(lightScheme),
          darkTheme: _themeData(darkScheme),
          home: TravelPlannerShell(
            repository: MockTravelRepository(),
            themeSource: _themeSource,
            onThemeChanged: (source) => setState(() => _themeSource = source),
          ),
        );
      },
    );
  }

  ThemeData _themeData(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: colorScheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}

class TravelPlannerShell extends StatefulWidget {
  const TravelPlannerShell({
    required this.repository,
    required this.themeSource,
    required this.onThemeChanged,
    super.key,
  });

  final MockTravelRepository repository;
  final ThemeSource themeSource;
  final ValueChanged<ThemeSource> onThemeChanged;

  @override
  State<TravelPlannerShell> createState() => _TravelPlannerShellState();
}

class _TravelPlannerShellState extends State<TravelPlannerShell> {
  AppTab _tab = AppTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title),
            Text(
              _subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showInfo(
              'Notifications',
              'Itinerary reminders and saved trip updates will appear here once backend messaging is connected.',
            ),
          ),
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpCenter,
          ),
        ],
      ),
      drawer: _NavigationDrawer(
        selectedTab: _tab,
        onSelected: (tab) {
          Navigator.pop(context);
          setState(() => _tab = tab);
        },
        onHelp: () {
          Navigator.pop(context);
          _showHelpCenter();
        },
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.02, 0.01),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: _body,
          ),
        ),
      ),
      floatingActionButton: _tab == AppTab.itinerary
          ? FloatingActionButton(
              tooltip: 'Add attraction or activity',
              onPressed: () => _showEditItemSheet(),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) {
          setState(() => _tab = AppTab.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Itinerary',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String get _title {
    switch (_tab) {
      case AppTab.home:
        return 'Wayfare';
      case AppTab.explore:
        return 'Explore Map';
      case AppTab.itinerary:
        return 'Itinerary';
      case AppTab.saved:
        return 'Saved Trips';
      case AppTab.profile:
        return 'Profile';
    }
  }

  String get _subtitle {
    switch (_tab) {
      case AppTab.home:
        return 'Discover, plan, and reopen saved trips';
      case AppTab.explore:
        return 'Markers, route context, and bottom sheet details';
      case AppTab.itinerary:
        return 'Timeline with editable travel plan items';
      case AppTab.saved:
        return 'Upcoming, saved destinations, and history';
      case AppTab.profile:
        return 'Account, preferences, theme, and support';
    }
  }

  Widget get _body {
    switch (_tab) {
      case AppTab.home:
        return _HomeScreen(
          repository: widget.repository,
          onOpenMap: () => setState(() => _tab = AppTab.explore),
          onOpenSaved: () => setState(() => _tab = AppTab.saved),
          onCreateItinerary: () => setState(() => _tab = AppTab.itinerary),
          onDestinationDetail: _showDestinationDetail,
          onAddDestination: (destination) => _addMockItem(
            destination.name,
            'Explore ${destination.theme}',
            'Added from recommendations.',
          ),
          onShowInfo: _showInfo,
        );
      case AppTab.explore:
        return _ExploreScreen(
          places: widget.repository.mapPlaces,
          onPlaceSelected: _showPlaceSheet,
          onRetry: () => _toast('Mock map data refreshed'),
        );
      case AppTab.itinerary:
        return _ItineraryScreen(
          days: widget.repository.itineraryDays,
          onAddDay: _showAddDaySheet,
          onEdit: (item) => _showEditItemSheet(item: item),
          onDelete: _confirmDelete,
          onReorder: _reorderItem,
          onDuplicate: _duplicateItem,
          onOpenMap: () => setState(() => _tab = AppTab.explore),
          onSave: () => _toast(
            'Plan saved locally. Backend storage can replace mock data later.',
          ),
        );
      case AppTab.saved:
        return _SavedScreen(
          trips: widget.repository.savedTrips,
          onAdd: (trip) => _addMockItem(
            trip.destination,
            'Reused saved trip idea',
            'Added from saved trips.',
          ),
          onShowInfo: _showInfo,
          onRemove: () => _toast('Remove from saved placeholder'),
        );
      case AppTab.profile:
        return _ProfileScreen(
          repository: widget.repository,
          themeSource: widget.themeSource,
          onThemePick: _showThemeChooser,
          onHelp: _showHelpCenter,
          onFeedback: _showFeedbackSheet,
          onOnboarding: _showOnboarding,
          onShowInfo: _showInfo,
          onToast: _toast,
        );
    }
  }

  void _addMockItem(String place, String activity, String note) {
    _showQuickAddToDaySheet(place: place, activity: activity, note: note);
  }

  void _ensureDefaultDay() {
    if (widget.repository.itineraryDays.isNotEmpty) {
      return;
    }
    setState(() {
      widget.repository.itineraryDays.add(
        ItineraryDay(
          title: 'Day 1',
          date: 'TBD',
          city: 'TBD',
          reminder: 'Reminder: review route before departure',
          items: [],
        ),
      );
    });
  }

  void _showQuickAddToDaySheet({
    required String place,
    required String activity,
    required String note,
  }) {
    _ensureDefaultDay();
    var selectedDayIndex = 0;
    final time = TextEditingController(text: 'Flexible');

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SheetPadding(
              bottomInset: MediaQuery.viewInsetsOf(context).bottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Add to Itinerary',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(place, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDayIndex,
                    decoration: const InputDecoration(labelText: 'Target day'),
                    items: [
                      for (var i = 0;
                          i < widget.repository.itineraryDays.length;
                          i++)
                        DropdownMenuItem<int>(
                          value: i,
                          child: Text(
                            '${widget.repository.itineraryDays[i].title} | ${widget.repository.itineraryDays[i].date}',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => selectedDayIndex = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: time,
                    decoration:
                        const InputDecoration(labelText: 'Time', filled: true),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        widget.repository.itineraryDays[selectedDayIndex].items
                            .add(
                          ItineraryItem(
                            time: time.text.trim().isEmpty
                                ? 'Flexible'
                                : time.text.trim(),
                            place: place,
                            activity: activity,
                            note: note,
                            status: 'Unsaved changes',
                          ),
                        );
                      });
                      Navigator.pop(context);
                      _toast(
                          'Added to ${widget.repository.itineraryDays[selectedDayIndex].title}');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addDay({
    required String title,
    required String date,
    required String city,
    required String reminder,
  }) {
    setState(() {
      widget.repository.itineraryDays.add(
        ItineraryDay(
          title: title,
          date: date,
          city: city,
          reminder: reminder,
          items: [],
        ),
      );
    });
    _toast('New day created');
  }

  void _reorderItem(ItineraryDay day, int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = day.items.removeAt(oldIndex);
      item.status = 'Unsaved changes';
      day.items.insert(newIndex, item);
    });
  }

  void _duplicateItem(ItineraryDay day, ItineraryItem item) {
    setState(() {
      final index = day.items.indexOf(item);
      day.items.insert(
        index < 0 ? day.items.length : index + 1,
        ItineraryItem(
          time: item.time,
          place: item.place,
          activity: '${item.activity} copy',
          note: item.note,
          status: 'Unsaved changes',
        ),
      );
    });
    _toast('Item duplicated');
  }

  void _showAddDaySheet() {
    final title = TextEditingController(
      text: 'Day ${widget.repository.itineraryDays.length + 1}',
    );
    final date = TextEditingController();
    final city = TextEditingController();
    final reminder = TextEditingController(
      text: 'Reminder: review route before departure',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _SheetPadding(
          bottomInset: MediaQuery.viewInsetsOf(context).bottom,
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Create New Day',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(
                      labelText: 'Day title', filled: true),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: date,
                  decoration:
                      const InputDecoration(labelText: 'Date', filled: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: city,
                  decoration:
                      const InputDecoration(labelText: 'City', filled: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reminder,
                  decoration: const InputDecoration(
                    labelText: 'Weather or reminder placeholder',
                    filled: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    _addDay(
                      title: title.text.trim(),
                      date: date.text.trim().isEmpty ? 'TBD' : date.text.trim(),
                      city: city.text.trim().isEmpty ? 'TBD' : city.text.trim(),
                      reminder: reminder.text.trim().isEmpty
                          ? 'Reminder: review route before departure'
                          : reminder.text.trim(),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Add Day'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDestinationDetail(Destination destination) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _SheetPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(destination.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(destination.summary),
              const SizedBox(height: 12),
              Chip(label: Text(destination.reason)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _addMockItem(
                        destination.name,
                        'Plan visit',
                        'Added from destination detail.',
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Itinerary'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _tab = AppTab.explore);
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open Map'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toast('Saved destination'),
                    icon: const Icon(Icons.bookmark_border),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlaceSheet(MapPlace place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _SheetPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(place.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('${place.category} | ${place.distance} | ${place.rating}'),
              const SizedBox(height: 12),
              Text(place.description),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _addMockItem(place.name, 'Visit ${place.category}',
                          place.description);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Itinerary'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toast('Place saved'),
                    icon: const Icon(Icons.bookmark_border),
                    label: const Text('Save Place'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showInfo(place.name, place.description),
                    icon: const Icon(Icons.search),
                    label: const Text('View Detail'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditItemSheet({ItineraryItem? item}) {
    final isNew = item == null;
    if (isNew) {
      _ensureDefaultDay();
    }
    final days = widget.repository.itineraryDays;
    final currentDayIndex = isNew
        ? math.max(0, days.length - 1)
        : days.indexWhere((day) => day.items.contains(item));
    var selectedDayIndex = currentDayIndex < 0 ? 0 : currentDayIndex;
    final time = TextEditingController(text: item?.time ?? '15:30');
    final place = TextEditingController(text: item?.place ?? '');
    final activity = TextEditingController(text: item?.activity ?? '');
    final note = TextEditingController(text: item?.note ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SheetPadding(
              bottomInset: MediaQuery.viewInsetsOf(context).bottom,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isNew
                          ? 'Add Activity / Attraction'
                          : 'Edit Itinerary Item',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: selectedDayIndex,
                      decoration: const InputDecoration(
                        labelText: 'Target day',
                        filled: true,
                      ),
                      items: [
                        for (var i = 0; i < days.length; i++)
                          DropdownMenuItem<int>(
                            value: i,
                            child: Text('${days[i].title} | ${days[i].date}'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedDayIndex = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: time,
                      decoration: const InputDecoration(
                        labelText: 'Time range',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: place,
                      decoration: const InputDecoration(
                        labelText: 'Place or attraction',
                        filled: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: activity,
                      decoration: const InputDecoration(
                        labelText: 'Activity',
                        filled: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: note,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        filled: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        setState(() {
                          final targetDay =
                              widget.repository.itineraryDays[selectedDayIndex];
                          if (isNew) {
                            targetDay.items.add(
                              ItineraryItem(
                                time: time.text.trim().isEmpty
                                    ? 'Flexible'
                                    : time.text.trim(),
                                place: place.text.trim(),
                                activity: activity.text.trim(),
                                note: note.text.trim(),
                                status: 'Unsaved changes',
                              ),
                            );
                          } else {
                            ItineraryDay? oldDay;
                            for (final day in widget.repository.itineraryDays) {
                              if (day.items.contains(item)) {
                                oldDay = day;
                                break;
                              }
                            }
                            item.time = time.text.trim().isEmpty
                                ? 'Flexible'
                                : time.text.trim();
                            item.place = place.text.trim();
                            item.activity = activity.text.trim();
                            item.note = note.text.trim();
                            item.status = 'Unsaved changes';
                            if (oldDay != null && oldDay != targetDay) {
                              oldDay.items.remove(item);
                              targetDay.items.add(item);
                            }
                          }
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(isNew ? 'Add Item' : 'Save Item'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  void _confirmDelete(ItineraryItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text(
          'This prevents accidental deletion while editing a trip timeline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                for (final day in widget.repository.itineraryDays) {
                  if (day.items.remove(item)) {
                    break;
                  }
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showThemeChooser() {
    var selected = widget.themeSource;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Color source'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Material You converts the selected source into coordinated Material 3 roles across buttons, cards, chips, sheets, and navigation.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final source in ThemeSource.values)
                    ListTile(
                      leading: Icon(
                        selected == source
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(source.label),
                      trailing: CircleAvatar(backgroundColor: source.seed),
                      onTap: () => setDialogState(() => selected = source),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  widget.onThemeChanged(selected);
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFeedbackSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _SheetPadding(
          bottomInset: MediaQuery.viewInsetsOf(context).bottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Contact / Feedback',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Issue category',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  filled: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _toast('Optional screenshot placeholder'),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Screenshot Placeholder'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _toast('Feedback queued locally');
                },
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOnboarding() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SheetPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Discover | Plan | Map',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const _InfoTile(
              icon: Icons.search,
              text:
                  'Discover: search cities, attractions, or travel themes from Home.',
            ),
            const SizedBox(height: 8),
            const _InfoTile(
              icon: Icons.list_alt_outlined,
              text:
                  'Plan: create a timeline with dates, places, activities, notes, and status feedback.',
            ),
            const SizedBox(height: 8),
            const _InfoTile(
              icon: Icons.map_outlined,
              text:
                  'Map: tap categorized markers to add places while keeping spatial context.',
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpCenter() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _SheetPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Help Center',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const SearchBar(
                leading: Icon(Icons.search),
                hintText: 'Search FAQ',
              ),
              const SizedBox(height: 12),
              for (final faq in widget.repository.supportFaqs) ...[
                _InfoTile(icon: Icons.help_outline, text: faq),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen({
    required this.repository,
    required this.onOpenMap,
    required this.onOpenSaved,
    required this.onCreateItinerary,
    required this.onDestinationDetail,
    required this.onAddDestination,
    required this.onShowInfo,
  });

  final MockTravelRepository repository;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenSaved;
  final VoidCallback onCreateItinerary;
  final ValueChanged<Destination> onDestinationDetail;
  final ValueChanged<Destination> onAddDestination;
  final void Function(String title, String message) onShowInfo;

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final selectedFilters = <String>{'Weekend Trip'};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SearchBar(
          leading: const Icon(Icons.search),
          hintText: 'Search city, attraction, or travel theme',
          trailing: [
            IconButton(
              tooltip: 'Filters',
              icon: const Icon(Icons.tune),
              onPressed: () => widget.onShowInfo(
                'Filters',
                'Weekend Trip, City Break, Nature, Food, Culture, Family, and Budget Friendly filters are available.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TravelHeroPanel(
          onOpenSaved: widget.onOpenSaved,
          onOpenMap: widget.onOpenMap,
          onCreateItinerary: widget.onCreateItinerary,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: widget.onCreateItinerary,
              icon: const Icon(Icons.add),
              label: const Text('Create New Itinerary'),
            ),
            FilledButton.tonalIcon(
              onPressed: widget.onOpenSaved,
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Upcoming Trip'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onOpenMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Explore Map'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in widget.repository.filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: selectedFilters.contains(filter),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? selectedFilters.add(filter)
                            : selectedFilters.remove(filter);
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
          title: 'Recommended for You',
          action: 'Rule-based suggestions',
        ),
        const SizedBox(height: 12),
        for (final destination in widget.repository.destinations) ...[
          _DestinationCard(
            destination: destination,
            onDetail: () => widget.onDestinationDetail(destination),
            onSave: () =>
                widget.onShowInfo('Saved', '${destination.name} saved.'),
            onAdd: () => widget.onAddDestination(destination),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        const _SectionHeader(
          title: 'Planning Guides',
          action: 'Help / How to Start',
        ),
        const SizedBox(height: 12),
        for (final guide in widget.repository.guideCards) ...[
          _InfoTile(icon: Icons.help_outline, text: guide),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NavigationDrawer extends StatelessWidget {
  const _NavigationDrawer({
    required this.selectedTab,
    required this.onSelected,
    required this.onHelp,
  });

  final AppTab selectedTab;
  final ValueChanged<AppTab> onSelected;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: scheme.primaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: const Icon(Icons.route_outlined),
                  ),
                  const SizedBox(height: 12),
                  Text('Wayfare',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                    'Discover, plan, save, and map trips',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _DrawerDestination(
              icon: Icons.home_outlined,
              label: 'Home Dashboard',
              selected: selectedTab == AppTab.home,
              onTap: () => onSelected(AppTab.home),
            ),
            _DrawerDestination(
              icon: Icons.map_outlined,
              label: 'Explore Map',
              selected: selectedTab == AppTab.explore,
              onTap: () => onSelected(AppTab.explore),
            ),
            _DrawerDestination(
              icon: Icons.list_alt_outlined,
              label: 'Itinerary Timeline',
              selected: selectedTab == AppTab.itinerary,
              onTap: () => onSelected(AppTab.itinerary),
            ),
            _DrawerDestination(
              icon: Icons.bookmark_border,
              label: 'Saved Trips',
              selected: selectedTab == AppTab.saved,
              onTap: () => onSelected(AppTab.saved),
            ),
            _DrawerDestination(
              icon: Icons.person_outline,
              label: 'Profile & Settings',
              selected: selectedTab == AppTab.profile,
              onTap: () => onSelected(AppTab.profile),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help Center'),
              onTap: onHelp,
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelHeroPanel extends StatelessWidget {
  const _TravelHeroPanel({
    required this.onOpenSaved,
    required this.onOpenMap,
    required this.onCreateItinerary,
  });

  final VoidCallback onOpenSaved;
  final VoidCallback onOpenMap;
  final VoidCallback onCreateItinerary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekend plan is taking shape',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onTertiaryContainer,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '5 planned stops, 2 days, Hangzhou route context ready.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onTertiaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: scheme.tertiary,
                  foregroundColor: scheme.onTertiary,
                  child: const Icon(Icons.travel_explore),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onCreateItinerary,
                  icon: const Icon(Icons.add),
                  label: const Text('Plan'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Map'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSaved,
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Saved'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationVisual extends StatelessWidget {
  const _DestinationVisual({
    required this.tone,
    required this.title,
    required this.icon,
  });

  final Color tone;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final onTone = _onColor(tone);
    return SizedBox(
      height: 132,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tone,
              Color.lerp(tone, Colors.black, 0.22)!,
              Color.lerp(tone, Colors.white, 0.16)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: 12,
              child:
                  Icon(icon, size: 118, color: onTone.withValues(alpha: 0.18)),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: onTone.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: onTone.withValues(alpha: 0.24)),
                    ),
                    child: Icon(icon, color: onTone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: onTone,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 22,
              right: 88,
              top: 28,
              child: CustomPaint(
                size: const Size(double.infinity, 34),
                painter:
                    _RouteLinePainter(color: onTone.withValues(alpha: 0.38)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  const _RouteLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(
        size.width * 0.22,
        0,
        size.width * 0.48,
        size.height,
        size.width * 0.72,
        size.height * 0.24,
      )
      ..quadraticBezierTo(
          size.width * 0.86, -2, size.width, size.height * 0.45);
    canvas.drawPath(path, paint);
    for (final x in [0.0, size.width * 0.48, size.width]) {
      canvas.drawCircle(
          Offset(x, x == 0 ? size.height * 0.75 : size.height * 0.45),
          3,
          paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.onDetail,
    required this.onSave,
    required this.onAdd,
  });

  final Destination destination;
  final VoidCallback onDetail;
  final VoidCallback onSave;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: destination.priority
          ? scheme.primaryContainer
          : scheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DestinationVisual(
            tone: destination.tone,
            title: destination.theme,
            icon: destination.theme.contains('Food')
                ? Icons.restaurant_menu_outlined
                : destination.theme.contains('City')
                    ? Icons.location_city_outlined
                    : destination.theme.contains('Culture')
                        ? Icons.temple_buddhist_outlined
                        : Icons.landscape_outlined,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        destination.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(destination.duration),
                  ],
                ),
                const SizedBox(height: 8),
                Text(destination.summary),
                const SizedBox(height: 10),
                Chip(label: Text(destination.reason)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onDetail,
                      icon: const Icon(Icons.search),
                      label: const Text('View Detail'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save'),
                    ),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
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

enum _MapMode { explore, planned }

class _ExploreScreen extends StatefulWidget {
  const _ExploreScreen({
    required this.places,
    required this.onPlaceSelected,
    required this.onRetry,
  });

  final List<MapPlace> places;
  final ValueChanged<MapPlace> onPlaceSelected;
  final VoidCallback onRetry;

  @override
  State<_ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<_ExploreScreen> {
  _MapMode _mode = _MapMode.explore;
  late final Set<String> _selectedCategories =
      widget.places.map((place) => place.category).toSet();

  List<MapPlace> get _visiblePlaces {
    return widget.places
        .where((place) => _selectedCategories.contains(place.category))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = widget.places.map((place) => place.category).toSet();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchBar(
            leading: const Icon(Icons.search),
            hintText: 'Search map places or planned stops',
            trailing: [
              IconButton(
                tooltip: 'Refresh local map data',
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_MapMode>(
                  segments: const [
                    ButtonSegment(
                      value: _MapMode.explore,
                      icon: Icon(Icons.travel_explore),
                      label: Text('Explore'),
                    ),
                    ButtonSegment(
                      value: _MapMode.planned,
                      icon: Icon(Icons.route_outlined),
                      label: Text('Planned'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final category in categories) ...[
                FilterChip(
                  label: Text(category),
                  selected: _selectedCategories.contains(category),
                  onSelected: (selected) {
                    setState(() {
                      selected
                          ? _selectedCategories.add(category)
                          : _selectedCategories.remove(category);
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    _ChinaTravelMap(
                      places: _visiblePlaces,
                      mode: _mode,
                      onPlaceSelected: widget.onPlaceSelected,
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _MapStatusBar(
                        mode: _mode,
                        visibleCount: _visiblePlaces.length,
                        onRetry: widget.onRetry,
                      ),
                    ),
                    if (_visiblePlaces.isEmpty)
                      Center(
                        child: Card.filled(
                          color: scheme.surface.withValues(alpha: 0.94),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.map_outlined, size: 32),
                                const SizedBox(height: 8),
                                const Text('No visible map markers'),
                                const SizedBox(height: 8),
                                FilledButton.tonal(
                                  onPressed: () {
                                    setState(() {
                                      _selectedCategories
                                        ..clear()
                                        ..addAll(categories);
                                    });
                                  },
                                  child: const Text('Reset filters'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapStatusBar extends StatelessWidget {
  const _MapStatusBar({
    required this.mode,
    required this.visibleCount,
    required this.onRetry,
  });

  final _MapMode mode;
  final int visibleCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mode == _MapMode.explore
                    ? 'China itinerary map | drag, zoom, tap markers'
                    : 'Planned route view | $visibleCount visible stops',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ChinaTravelMap extends StatelessWidget {
  const _ChinaTravelMap({
    required this.places,
    required this.mode,
    required this.onPlaceSelected,
  });

  final List<MapPlace> places;
  final _MapMode mode;
  final ValueChanged<MapPlace> onPlaceSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          math.max(620, constraints.maxWidth),
          math.max(520, constraints.maxHeight),
        );
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(120),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _ChinaMapPainter(
                    scheme: scheme,
                    places: places,
                    mode: mode,
                  ),
                ),
                for (var index = 0; index < places.length; index++)
                  _MapMarkerButton(
                    place: places[index],
                    offset: _projectChinaPoint(places[index].point, size) +
                        _markerNudge(index),
                    onTap: () => onPlaceSelected(places[index]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapMarkerButton extends StatelessWidget {
  const _MapMarkerButton({
    required this.place,
    required this.offset,
    required this.onTap,
  });

  final MapPlace place;
  final Offset offset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: offset.dx - 24,
      top: offset.dy - 24,
      child: Tooltip(
        message: place.name,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            fixedSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
          ),
          onPressed: onTap,
          child: Icon(place.icon, size: 22),
        ),
      ),
    );
  }
}

class _ChinaMapPainter extends CustomPainter {
  const _ChinaMapPainter({
    required this.scheme,
    required this.places,
    required this.mode,
  });

  final ColorScheme scheme;
  final List<MapPlace> places;
  final _MapMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final waterPaint = Paint()
      ..color = scheme.primaryContainer.withValues(alpha: 0.28);
    canvas.drawRect(Offset.zero & size, waterPaint);

    final landPath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.29)
      ..lineTo(size.width * 0.25, size.height * 0.18)
      ..lineTo(size.width * 0.38, size.height * 0.16)
      ..lineTo(size.width * 0.48, size.height * 0.22)
      ..lineTo(size.width * 0.60, size.height * 0.18)
      ..lineTo(size.width * 0.76, size.height * 0.26)
      ..lineTo(size.width * 0.86, size.height * 0.40)
      ..lineTo(size.width * 0.82, size.height * 0.52)
      ..lineTo(size.width * 0.72, size.height * 0.56)
      ..lineTo(size.width * 0.69, size.height * 0.70)
      ..lineTo(size.width * 0.58, size.height * 0.78)
      ..lineTo(size.width * 0.45, size.height * 0.73)
      ..lineTo(size.width * 0.35, size.height * 0.83)
      ..lineTo(size.width * 0.24, size.height * 0.72)
      ..lineTo(size.width * 0.19, size.height * 0.56)
      ..lineTo(size.width * 0.09, size.height * 0.49)
      ..lineTo(size.width * 0.12, size.height * 0.37)
      ..close();

    final landFill = Paint()..color = scheme.surface;
    final landStroke = Paint()
      ..color = scheme.outline.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(landPath, landFill);
    canvas.drawPath(landPath, landStroke);

    final provincePaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final line in _provinceLines(size)) {
      canvas.drawPath(line, provincePaint);
    }

    _drawCityLabel(canvas, size, 'Beijing', const LatLng(39.9042, 116.4074));
    _drawCityLabel(canvas, size, 'Shanghai', const LatLng(31.2304, 121.4737));
    _drawCityLabel(canvas, size, 'Hangzhou', const LatLng(30.2741, 120.1551));
    _drawCityLabel(canvas, size, 'Chengdu', const LatLng(30.5728, 104.0668));

    if (places.length > 1) {
      final routePaint = Paint()
        ..color = (mode == _MapMode.planned ? scheme.primary : scheme.tertiary)
            .withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final route = Path();
      for (var index = 0; index < places.length; index++) {
        final point =
            _projectChinaPoint(places[index].point, size) + _markerNudge(index);
        if (index == 0) {
          route.moveTo(point.dx, point.dy);
        } else {
          route.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(route, routePaint);
    }

    final southSeaPaint = Paint()
      ..color = scheme.tertiaryContainer.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final inset = Rect.fromLTWH(
      size.width * 0.76,
      size.height * 0.68,
      size.width * 0.12,
      size.height * 0.18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, const Radius.circular(8)),
      southSeaPaint,
    );
  }

  void _drawCityLabel(Canvas canvas, Size size, String text, LatLng point) {
    final position = _projectChinaPoint(point, size);
    final paragraph = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(
      position.dx + 8,
      position.dy - 10,
      paragraph.width + 10,
      paragraph.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = scheme.surface.withValues(alpha: 0.82),
    );
    paragraph.paint(canvas, Offset(rect.left + 5, rect.top + 3));
    canvas.drawCircle(position, 3, Paint()..color = scheme.primary);
  }

  List<Path> _provinceLines(Size size) {
    return [
      Path()
        ..moveTo(size.width * 0.24, size.height * 0.27)
        ..quadraticBezierTo(
          size.width * 0.42,
          size.height * 0.34,
          size.width * 0.63,
          size.height * 0.28,
        ),
      Path()
        ..moveTo(size.width * 0.23, size.height * 0.47)
        ..quadraticBezierTo(
          size.width * 0.46,
          size.height * 0.42,
          size.width * 0.75,
          size.height * 0.47,
        ),
      Path()
        ..moveTo(size.width * 0.36, size.height * 0.20)
        ..quadraticBezierTo(
          size.width * 0.42,
          size.height * 0.48,
          size.width * 0.35,
          size.height * 0.76,
        ),
      Path()
        ..moveTo(size.width * 0.57, size.height * 0.22)
        ..quadraticBezierTo(
          size.width * 0.58,
          size.height * 0.49,
          size.width * 0.61,
          size.height * 0.74,
        ),
    ];
  }

  @override
  bool shouldRepaint(covariant _ChinaMapPainter oldDelegate) {
    return oldDelegate.scheme != scheme ||
        oldDelegate.places != places ||
        oldDelegate.mode != mode;
  }
}

Offset _projectChinaPoint(LatLng point, Size size) {
  const minLng = 73.0;
  const maxLng = 135.0;
  const minLat = 18.0;
  const maxLat = 54.0;
  final x = ((point.longitude - minLng) / (maxLng - minLng)).clamp(0.0, 1.0);
  final y = ((maxLat - point.latitude) / (maxLat - minLat)).clamp(0.0, 1.0);
  return Offset(
      size.width * (0.08 + x * 0.82), size.height * (0.12 + y * 0.76));
}

Offset _markerNudge(int index) {
  const nudges = [
    Offset.zero,
    Offset(24, -18),
    Offset(-26, 18),
    Offset(30, 20),
    Offset(-28, -20),
    Offset(0, 30),
  ];
  return nudges[index % nudges.length];
}

class _ItineraryScreen extends StatelessWidget {
  const _ItineraryScreen({
    required this.days,
    required this.onAddDay,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    required this.onDuplicate,
    required this.onOpenMap,
    required this.onSave,
  });

  final List<ItineraryDay> days;
  final VoidCallback onAddDay;
  final ValueChanged<ItineraryItem> onEdit;
  final ValueChanged<ItineraryItem> onDelete;
  final void Function(ItineraryDay day, int oldIndex, int newIndex) onReorder;
  final void Function(ItineraryDay day, ItineraryItem item) onDuplicate;
  final VoidCallback onOpenMap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        Card.filled(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.route_outlined,
                        color: scheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${days.length} day plan',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Local draft now supports day creation, targeted add, edit, duplicate, and drag reorder.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Plan'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onAddDay,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Add Day'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open Map'),
                    ),
                  ],
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
                  Text('No itinerary days yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                      'Create a day first, then add attractions or activities.'),
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
        for (final day in days) ...[
          _SectionHeader(title: day.title, action: '${day.date} | ${day.city}'),
          const SizedBox(height: 4),
          Text(day.reminder),
          const SizedBox(height: 10),
          if (day.items.isEmpty)
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No activities yet. Use the add button to create the first item.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: day.items.length,
              onReorder: (oldIndex, newIndex) =>
                  onReorder(day, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final item = day.items[index];
                return Padding(
                  key: ValueKey(item.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ItineraryItemCard(
                    item: item,
                    reorderIndex: index,
                    onEdit: () => onEdit(item),
                    onDelete: () => onDelete(item),
                    onDuplicate: () => onDuplicate(day, item),
                    onOpenMap: onOpenMap,
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ItineraryItemCard extends StatelessWidget {
  const _ItineraryItemCard({
    required this.item,
    required this.reorderIndex,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  final ItineraryItem item;
  final int reorderIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  Icon(Icons.circle, color: scheme.primary, size: 14),
                  const SizedBox(height: 8),
                  Text(
                    item.time,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.activity,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(item.place),
                  const SizedBox(height: 8),
                  Text(item.note),
                  const SizedBox(height: 8),
                  Chip(label: Text(item.status)),
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      IconButton(
                        tooltip: 'Duplicate',
                        onPressed: onDuplicate,
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      Tooltip(
                        message: 'Drag to reorder',
                        child: ReorderableDragStartListener(
                          index: reorderIndex,
                          child: SizedBox.square(
                            dimension: 40,
                            child: Icon(
                              Icons.drag_indicator,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open map',
                        onPressed: onOpenMap,
                        icon: const Icon(Icons.map_outlined),
                      ),
                    ],
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

class _SavedScreen extends StatefulWidget {
  const _SavedScreen({
    required this.trips,
    required this.onAdd,
    required this.onShowInfo,
    required this.onRemove,
  });

  final List<SavedTrip> trips;
  final ValueChanged<SavedTrip> onAdd;
  final void Function(String title, String message) onShowInfo;
  final VoidCallback onRemove;

  @override
  State<_SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<_SavedScreen> {
  final folders = <String>{'Weekend'};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const SearchBar(
          leading: Icon(Icons.search),
          hintText: 'Search saved trips, folders, or destinations',
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Upcoming Trips', action: 'Nearest first'),
        const SizedBox(height: 10),
        for (final trip in widget.trips.where((trip) => trip.upcoming)) ...[
          _SavedTripCard(
            trip: trip,
            onAdd: () => widget.onAdd(trip),
            onDetail: () => widget.onShowInfo(
              trip.destination,
              '${trip.dateRange}\n${trip.itemCount}\n${trip.lastUpdated}',
            ),
            onRemove: widget.onRemove,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        const _SectionHeader(
          title: 'Wishlists & Folders',
          action: 'Weekend | Family | Food | Nature',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final folder in [
              'Weekend',
              'Family',
              'Food',
              'Nature',
              'City Break'
            ])
              FilterChip(
                label: Text(folder),
                selected: folders.contains(folder),
                onSelected: (selected) {
                  setState(() {
                    selected ? folders.add(folder) : folders.remove(folder);
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Past Trips', action: 'Travel history'),
        const SizedBox(height: 10),
        for (final trip in widget.trips.where((trip) => !trip.upcoming)) ...[
          _SavedTripCard(
            trip: trip,
            onAdd: () => widget.onAdd(trip),
            onDetail: () => widget.onShowInfo(
              trip.destination,
              '${trip.dateRange}\n${trip.itemCount}\n${trip.lastUpdated}',
            ),
            onRemove: widget.onRemove,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SavedTripCard extends StatelessWidget {
  const _SavedTripCard({
    required this.trip,
    required this.onDetail,
    required this.onAdd,
    required this.onRemove,
  });

  final SavedTrip trip;
  final VoidCallback onDetail;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: trip.upcoming ? scheme.primaryContainer : scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.destination,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(trip.folder)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${trip.dateRange} | ${trip.itemCount} | ${trip.lastUpdated}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.search),
                  label: const Text('View Detail'),
                ),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Itinerary'),
                ),
                OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen({
    required this.repository,
    required this.themeSource,
    required this.onThemePick,
    required this.onHelp,
    required this.onFeedback,
    required this.onOnboarding,
    required this.onShowInfo,
    required this.onToast,
  });

  final MockTravelRepository repository;
  final ThemeSource themeSource;
  final VoidCallback onThemePick;
  final VoidCallback onHelp;
  final VoidCallback onFeedback;
  final VoidCallback onOnboarding;
  final void Function(String title, String message) onShowInfo;
  final ValueChanged<String> onToast;

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  final interests = <String>{'Nature', 'Foodie'};
  String budget = 'Medium';
  final styles = <String>{'Short Trip'};
  bool notifications = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card.filled(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Text('W',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guest traveler',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Phone verification and social login are front-end placeholders until backend auth is available.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _LoginCard(onToast: widget.onToast),
        const SizedBox(height: 16),
        const _SectionHeader(
          title: 'Travel Preferences',
          action: 'Used by recommendations',
        ),
        const SizedBox(height: 10),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Interest chips'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in widget.repository.preferences)
                      FilterChip(
                        label: Text(tag),
                        selected: interests.contains(tag),
                        onSelected: (selected) {
                          setState(() {
                            selected
                                ? interests.add(tag)
                                : interests.remove(tag);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Budget selector'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in ['Low', 'Medium', 'High', 'Flexible'])
                      ChoiceChip(
                        label: Text(value),
                        selected: budget == value,
                        onSelected: (_) => setState(() => budget = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Travel style selector'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final style in [
                      'Solo',
                      'Couple',
                      'Friends',
                      'Family',
                      'Short Trip',
                      'Long Trip',
                    ])
                      FilterChip(
                        label: Text(style),
                        selected: styles.contains(style),
                        onSelected: (selected) {
                          setState(() {
                            selected ? styles.add(style) : styles.remove(style);
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
            title: 'Settings & Customization', action: 'Material You'),
        const SizedBox(height: 10),
        Card.outlined(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language'),
                subtitle: const Text('English'),
                onTap: () => widget.onToast('Language settings placeholder'),
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Currency'),
                subtitle: const Text('CNY'),
                onTap: () => widget.onToast('Currency settings placeholder'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Push notifications'),
                subtitle:
                    const Text('Itinerary reminders and saved trip updates'),
                value: notifications,
                onChanged: (value) => setState(() => notifications = value),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy'),
                subtitle: const Text('Saved trips and personal travel data'),
                onTap: () => widget.onShowInfo(
                  'Privacy',
                  'Privacy controls are grouped here for account, saved trips, and personal travel data visibility.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Appearance'),
                subtitle: Text(widget.themeSource.label),
                onTap: widget.onThemePick,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
            title: 'Support & Resources', action: 'Quick access'),
        const SizedBox(height: 10),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: widget.onHelp,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help Center'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onFeedback,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Contact / Feedback'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onOnboarding,
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Onboarding Tips'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.onToast});

  final ValueChanged<String> onToast;

  @override
  Widget build(BuildContext context) {
    var hasPhone = false;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Easy Account Setup',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                filled: true,
              ),
              onChanged: (value) => hasPhone = value.trim().isNotEmpty,
            ),
            const SizedBox(height: 12),
            const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Verification code',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onToast(
                      'Verification code flow is ready for backend integration.'),
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Send Code'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (!hasPhone) {
                      onToast('Phone required');
                    } else {
                      onToast('Logged in locally as guest');
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Login'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onToast('Social login placeholder'),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Google'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onToast('Social login placeholder'),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WeChat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          Text(
            action!,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _SheetPadding extends StatelessWidget {
  const _SheetPadding({required this.child, this.bottomInset = 0});

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: child,
      ),
    );
  }
}

Color _onColor(Color color) {
  return color.computeLuminance() > 0.45
      ? const Color(0xFF111418)
      : Colors.white;
}
