import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/event_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/category_helper.dart';
import 'event_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with AutomaticKeepAliveClientMixin{

  @override
  bool get wantKeepAlive => true;

  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();

  bool _loadingLocation = true;
  bool _loadingEvents = true;
  List<Event> _allEvents = [];
  List<Event> _sortedEvents = [];
  LatLng? _userLocation;
  String _sortBy = 'distance'; // 'distance', 'date'
  String? _filterCategory; // null = all, or specific category
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
      });
      _loadEvents();
    } else {
      setState(() {
        _loadingLocation = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loadingEvents = true;
    });

    final events = await _firebaseService.getEvents();
    // Filter out expired events
    final upcomingEvents = events.where((e) => !e.isExpired).toList();
    setState(() {
      _allEvents = upcomingEvents;
    });
    _sortEvents(upcomingEvents);

    setState(() {
      _loadingEvents = false;
    });
  }

  void _sortEvents(List<Event> events) {
    // First, apply search filter
    List<Event> searchFiltered = events;
    if (_searchQuery.isNotEmpty) {
      searchFiltered = events.where((event) {
        final query = _searchQuery.toLowerCase();
        return event.title.toLowerCase().contains(query) ||
            event.description.toLowerCase().contains(query) ||
            event.category.toLowerCase().contains(query) ||
            event.locationName.toLowerCase().contains(query);
      }).toList();
    }

    // Then, apply category filter
    List<Event> filteredEvents = searchFiltered;
    if (_filterCategory != null) {
      filteredEvents = searchFiltered.where((event) => event.category == _filterCategory).toList();
    }

    // Then sort the filtered events
    final sortedEvents = List<Event>.from(filteredEvents);

    switch (_sortBy) {
      case 'distance':
        if (_locationService.currentPosition != null) {
          sortedEvents.sort((a, b) {
            final distA = _locationService.calculateDistance(
              _locationService.currentPosition!.latitude,
              _locationService.currentPosition!.longitude,
              a.latitude,
              a.longitude,
            );
            final distB = _locationService.calculateDistance(
              _locationService.currentPosition!.latitude,
              _locationService.currentPosition!.longitude,
              b.latitude,
              b.longitude,
            );
            return distA.compareTo(distB);
          });
        }
        break;
      case 'date':
        sortedEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        break;
    }

    setState(() {
      _sortedEvents = sortedEvents;
    });
  }

  double? _getDistance(Event event) {
    return _locationService.getDistanceToPoint(event.latitude, event.longitude);
  }

  void _openFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMapView(
          events: _sortedEvents,
          userLocation: _userLocation,
        ),
      ),
    );
  }

  void _showSortOptions() {
    final categories = ['Tech', 'Health', 'Culture', 'Sports', 'Volunteer', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Sort & Filter',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Distance (Nearest First)'),
                trailing: _sortBy == 'distance'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _sortBy = 'distance';
                  });
                  _sortEvents(_allEvents);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date (Upcoming First)'),
                trailing: _sortBy == 'date'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _sortBy = 'date';
                  });
                  _sortEvents(_allEvents);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              Text(
                'Filter by Category',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('All Categories'),
                trailing: _filterCategory == null
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _filterCategory = null;
                  });
                  _sortEvents(_allEvents);
                  Navigator.pop(context);
                },
              ),
              ...categories.map((category) {
                return ListTile(
                  leading: Icon(
                    CategoryHelper.getIconForCategory(category),
                    color: CategoryHelper.getColorForCategory(category),
                  ),
                  title: Text(category),
                  trailing: _filterCategory == category
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() {
                      _filterCategory = category;
                    });
                    _sortEvents(_allEvents);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loadingLocation
          ? _buildLoadingState()
          : RefreshIndicator(
        onRefresh: _loadEvents,
        child: _buildExploreView(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildExploreView() {
    return ListView(
      children: [
        // Search bar
        _buildSearchBar(),
        // Map preview box
        _buildMapPreviewBox(),
        // Events list header with sort button
        _buildEventsListHeader(),
        // Events list
        ..._buildEventsList(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search events...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _sortEvents(_allEvents);
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _sortEvents(_allEvents);
          });
        },
      ),
    );
  }

  Widget _buildMapPreviewBox() {
    return GestureDetector(
      onTap: _openFullScreenMap,
      child: Container(
        height: 250,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Map preview
              if (_userLocation != null)
                AbsorbPointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _userLocation!,
                      initialZoom: 13.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.aaspas',
                      ),
                      MarkerLayer(
                        markers: _sortedEvents.map((event) {
                          return Marker(
                            point: LatLng(event.latitude, event.longitude),
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 30,
                            ),
                          );
                        }).toList(),
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.map, size: 64, color: Colors.grey),
                  ),
                ),
              // Overlay
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Tap to view full map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Event count badge
              if (_sortedEvents.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event, size: 14, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          '${_sortedEvents.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsListHeader() {
    if (_loadingEvents) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Always show header with sort button (even if no events)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _sortedEvents.isEmpty
                  ? 'No events found'
                  : 'Events Near You (${_sortedEvents.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(width: 8),
          // Compact sort button - always visible
          InkWell(
            onTap: _showSortOptions,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _getSortLabel(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventsList() {
    // Show message if no events after filtering
    if (_sortedEvents.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.event_note, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  _filterCategory != null
                      ? 'No $_filterCategory events nearby'
                      : 'No events nearby',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_filterCategory != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterCategory = null;
                      });
                      _sortEvents(_allEvents);
                    },
                    child: const Text('Show all categories'),
                  ),
              ],
            ),
          ),
        ),
      ];
    }

    return _sortedEvents.map((event) {
      final distance = _getDistance(event);
      return _buildEventListTile(event, distance);
    }).toList();
  }

  String _getSortLabel() {
    String label = '';

    // Sort label
    switch (_sortBy) {
      case 'distance':
        label = 'Distance';
        break;
      case 'date':
        label = 'Date';
        break;
    }

    // Add filter if active
    if (_filterCategory != null) {
      label += ' • $_filterCategory';
    }

    return label;
  }

  Widget _buildEventListTile(Event event, double? distance) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: CategoryHelper.getColorForCategory(event.category).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            CategoryHelper.getIconForCategory(event.category),
            size: 28,
            color: CategoryHelper.getColorForCategory(event.category),
          ),
        ),
        title: Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  CategoryHelper.getIconForCategory(event.category),
                  size: 14,
                  color: CategoryHelper.getColorForCategory(event.category),
                ),
                const SizedBox(width: 4),
                Text(event.category, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                if (distance != null) ...[
                  const Icon(Icons.location_on, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('${distance.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  _formatDate(event.dateTime),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: event),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (eventDate == today) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }
}

// Full Screen Map View (same as before)
class FullScreenMapView extends StatefulWidget {
  final List<Event> events;
  final LatLng? userLocation;

  const FullScreenMapView({
    Key? key,
    required this.events,
    required this.userLocation,
  }) : super(key: key);

  @override
  State<FullScreenMapView> createState() => _FullScreenMapViewState();
}

class _FullScreenMapViewState extends State<FullScreenMapView> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  void _centerOnUser() {
    if (widget.userLocation != null) {
      _mapController.move(widget.userLocation!, 14.0);
    }
  }

  void _centerOnEvent(Event event) {
    final eventLocation = LatLng(event.latitude, event.longitude);
    _mapController.move(eventLocation, 16.0);
  }

  double? _getDistance(Event event) {
    return _locationService.getDistanceToPoint(event.latitude, event.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
      ),
      body: widget.userLocation == null
          ? const Center(
        child: Text('Location not available'),
      )
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.userLocation!,
              initialZoom: 14.0,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.aaspas',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: widget.events.map((event) {
                  final eventLocation = LatLng(event.latitude, event.longitude);
                  return Marker(
                    point: eventLocation,
                    width: 120,
                    height: 80,
                    child: GestureDetector(
                      onTap: () => _showEventBottomSheet(event),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.event,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userLocation!,
                    width: 60,
                    height: 60,
                    child: const Column(
                      children: [
                        Icon(
                          Icons.person_pin_circle,
                          size: 40,
                          color: Colors.blue,
                        ),
                        Text(
                          'You',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.events.length} events',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.userLocation != null
          ? FloatingActionButton.small(
        onPressed: _centerOnUser,
        child: const Icon(Icons.my_location),
        tooltip: 'My Location',
      )
          : null,
    );
  }

  void _showEventBottomSheet(Event event) {
    final distance = _getDistance(event);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (event.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      event.imageUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 48),
                        );
                      },
                    ),
                  ),
                if (event.imageUrl != null) const SizedBox(height: 16),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(event.category),
                      backgroundColor: Colors.blue[100],
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    if (distance != null)
                      Chip(
                        label: Text('${distance.toStringAsFixed(1)} km away'),
                        avatar: const Icon(Icons.location_on, size: 16),
                        backgroundColor: Colors.red[100],
                        labelStyle: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.locationName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(event.dateTime),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _centerOnEvent(event);
                        },
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Center'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailsScreen(event: event),
                            ),
                          );
                        },
                        icon: const Icon(Icons.info),
                        label: const Text('Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (eventDate == today) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }
}