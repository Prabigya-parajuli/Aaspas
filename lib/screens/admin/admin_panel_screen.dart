import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/firebase_service.dart';
import '../../services/user_service.dart';
import '../event_details_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'reports_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final CacheService _cacheService = CacheService();

  List<Event> _allEvents = [];
  bool _isLoading = true;

  final List<String> _adminEmails = [
    'adminaaspaas@gmail.com',
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoadEvents();
  }

  Future<void> _checkAdminAndLoadEvents() async {
    final user = _authService.currentUser;
    if (user == null || user.email == null) {
      Navigator.pop(context);
      return;
    }

    final isAdmin = _adminEmails.contains(user.email);
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. Admin only.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      Navigator.pop(context);
      return;
    }

    await _loadAllEvents();
  }

  Future<void> _loadAllEvents() async {
    setState(() => _isLoading = true);
    try {
      final events = await _firebaseService.getEvents().timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      );
      if (!mounted) return;
      setState(() {
        _allEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading events: $e')),
      );
    }
  }

  Future<void> _deleteEvent(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
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

    if (confirm != true) return;

    final success = await _firebaseService.deleteEvent(event.id);
    if (!mounted) return;

    if (success) {
      if (event.submittedBy.isNotEmpty) {
        await _userService.decrementEventsCreated(event.submittedBy);
        await _cacheService.clearUserCache(event.submittedBy);
      }
      await _cacheService.clearAllCache();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted')),
      );
      await _loadAllEvents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete event')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.red[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics, color: Colors.white),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnalyticsDashboardScreen(
                    events: _allEvents,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.flag, color: Colors.white),
            tooltip: 'Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportsScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.red[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Total Events', _allEvents.length.toString()),
                      _buildStatCard(
                        'Active',
                        _allEvents.where((e) => !e.isExpired).length.toString(),
                      ),
                      _buildStatCard(
                        'Expired',
                        _allEvents.where((e) => e.isExpired).length.toString(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _allEvents.isEmpty
                      ? const Center(child: Text('No events found'))
                      : RefreshIndicator(
                          onRefresh: _loadAllEvents,
                          child: ListView.builder(
                            itemCount: _allEvents.length,
                            itemBuilder: (context, index) {
                              final event = _allEvents[index];
                              return _buildEventListItem(event);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEventListItem(Event event) {
    final isExpired = event.isExpired;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isExpired ? Colors.grey[300] : Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isExpired ? Icons.event_busy : Icons.event,
            color: isExpired ? Colors.grey[600] : Colors.blue,
          ),
        ),
        title: Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: isExpired ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.category,
              style: const TextStyle(fontSize: 12),
            ),
            if (isExpired)
              Text(
                'Expired',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailsScreen(event: event),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deleteEvent(event),
            ),
          ],
        ),
      ),
    );
  }
}
