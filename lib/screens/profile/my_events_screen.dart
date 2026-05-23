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
import '../forms/add_event_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({Key? key}) : super(key: key);

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();

  List<Event> _myEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyEvents();
  }

  Future<void> _loadMyEvents() async {
    setState(() {
      _isLoading = true;
    });

    final userId = _authService.getCurrentUserId();
    print('🔍 Current User ID: $userId'); // DEBUG

    if (userId != null) {
      final events = await _firebaseService.getEventsByUser(userId);
      print('🔍 Events found: ${events.length}'); // DEBUG
      for (var event in events) {
        print('  - ${event.title} (submittedBy: ${event.submittedBy})'); // DEBUG
      }
      setState(() {
        _myEvents = events;
        _isLoading = false;
      });
    } else {
      print('❌ No user ID found'); // DEBUG
      setState(() {
        _isLoading = false;
      });
    }
  }

  double? _getDistance(Event event) {
    return _locationService.getDistanceToPoint(event.latitude, event.longitude);
  }

  Future<void> _deleteEvent(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _firebaseService.deleteEvent(event.id);
      if (success && mounted) {
        final userId = _authService.getCurrentUserId();
        await _cacheService.clearEventsCache();
        if (userId != null) {
          await _userService.decrementEventsCreated(userId);
          await _cacheService.clearUserCache(userId);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
        _loadMyEvents();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete event')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadMyEvents,
        child: _buildEventsList(),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_myEvents.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: EmptyStateWidget(
              icon: Icons.add_circle_outline,
              title: 'No Events Created',
              message: 'Share what\'s happening in your community! Create your first event and help others discover local activities.',
              actionLabel: 'Create Event',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddEventScreen()),
                ).then((_) => _loadMyEvents());
              },
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _myEvents.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '${_myEvents.length} event${_myEvents.length == 1 ? '' : 's'} created',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          );
        }

        final event = _myEvents[index - 1];
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
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
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
                } else if (value == 'delete') {
                  _deleteEvent(event);
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
