import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/location_service.dart';
import '../../services/category_helper.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../event_details_screen.dart';

class SavedEventsScreen extends StatefulWidget {
  const SavedEventsScreen({Key? key}) : super(key: key);

  @override
  State<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends State<SavedEventsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();

  List<Event> _savedEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedEvents();
  }

  Future<void> _loadSavedEvents() async {
    setState(() {
      _isLoading = true;
    });

    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      final savedEventIds = await _userService.getSavedEventIds(userId);
      if (savedEventIds.isNotEmpty) {
        final events = await _firebaseService.getEventsByIds(savedEventIds);
        // Filter out expired events
        final upcomingEvents = events
            .where((e) => !e.isExpired)
            .toList();
        setState(() {
          _savedEvents = upcomingEvents;
          _isLoading = false;
        });
      } else {
        setState(() {
          _savedEvents = [];
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double? _getDistance(Event event) {
    return _locationService.getDistanceToPoint(event.latitude, event.longitude);
  }

  Future<void> _unsaveEvent(Event event) async {
    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      final success = await _userService.unsaveEvent(userId, event.id);
      if (success && mounted) {
        await _firebaseService.decrementSaveCount(event.id);
        await _cacheService.clearUserCache(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event removed from saved')),
        );
        _loadSavedEvents();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unsave event')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Events'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadSavedEvents,
        child: _buildEventsList(),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_savedEvents.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: EmptyStateWidget(
              icon: Icons.bookmark_border,
              title: 'No Saved Events',
              message: 'Browse events and tap the bookmark icon to save them here for quick access!',
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _savedEvents.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '${_savedEvents.length} saved event${_savedEvents.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          );
        }

        final event = _savedEvents[index - 1];
        final distance = _getDistance(event);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: CategoryHelper.getColorForCategory(event.category)
                    .withOpacity(0.2),
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
                      Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 20),
                      SizedBox(width: 12),
                      Text('View Details'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'unsave',
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_remove, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Unsave', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'view') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                } else if (value == 'unsave') {
                  _unsaveEvent(event);
                }
              },
            ),
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
      },
    );
  }
}
