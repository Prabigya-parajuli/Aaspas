import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/category_helper.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/recommendation_service.dart';
import '../services/user_service.dart';
import '../widgets/email_verification_banner.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/event_card.dart';
import '../widgets/loading_skeleton.dart';
import 'event_details_screen.dart';
import 'forms/add_event_screen.dart';
import '../services/analytics_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  final RecommendationService _recommendationService = RecommendationService();
  final CacheService _cacheService = CacheService();
  final UserService _userService = UserService();

  bool _loadingLocation = true;
  bool _isRefreshing = false;
  bool _showingCachedData = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Event> _allEvents = [];
  List<Event> _recommendedEvents = [];
  List<Event> _trendingEvents = [];
  List<Event> _nearbyEvents = [];
  Map<String, int> _attendanceCounts = {};
  User? _currentUser;
  int _totalActiveEvents = 0;
  int _totalUsersCount = 0;
  String _topCategory = '';

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
    await _locationService.getCurrentLocation();
    await _loadUserData();
    await _loadEventsWithCache();
    if (mounted) {
      setState(() {
        _loadingLocation = false;
      });
    }
  }

  // NEW METHOD: Filter events within 5km
  List<Event> _filterEventsByDistance(List<Event> events) {
    if (_locationService.currentPosition == null) return events;

    return events.where((event) {
      final distance = _locationService.calculateDistance(
        _locationService.currentPosition!.latitude,
        _locationService.currentPosition!.longitude,
        event.latitude,
        event.longitude,
      );
      return distance <= 5.0; // Only events within 5km
    }).toList();
  }

  Future<void> _loadEventsWithCache() async {
    final cachedEvents = await _cacheService.getCachedEvents();
    if (cachedEvents != null && cachedEvents.isNotEmpty) {
      final upcomingCachedEvents =
      cachedEvents.where((event) => !event.isExpired).toList();
      setState(() {
        _allEvents = _filterEventsByDistance(upcomingCachedEvents);
        _showingCachedData = true;
      });
      if (_currentUser != null) {
        _generateRecommendations();
      } else {
        _sortEventsByDistance(upcomingCachedEvents);
      }
      await _loadAttendanceCounts(upcomingCachedEvents);
      print('Showing cached events instantly');
      _refreshFromFirebase(showFeedback: false);
      return;
    }

    await _loadEvents();
  }

  Future<void> _refreshFromFirebase({bool showFeedback = true}) async {
    try {
      setState(() => _isRefreshing = true);
      final events = await _firebaseService.getEvents();
      final upcomingEvents = events.where((event) => !event.isExpired).toList();

      if (!mounted) return;

      await _cacheService.cacheEvents(upcomingEvents);
      setState(() {
        _allEvents = _filterEventsByDistance(upcomingEvents);
        _isRefreshing = false;
        _showingCachedData = false;
      });

      if (_currentUser != null) {
        _generateRecommendations();
      } else {
        _sortEventsByDistance(upcomingEvents);
      }
      await _loadAttendanceCounts(upcomingEvents);
      _updateQuickStats();

      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Events refreshed')),
        );
      }
      print('Events refreshed from Firebase');
    } catch (e) {
      if (!mounted) return;

      final offlineEvents = await _cacheService.getCachedEventsOffline();
      if (_allEvents.isEmpty && offlineEvents != null && offlineEvents.isNotEmpty) {
        final upcomingOfflineEvents =
        offlineEvents.where((event) => !event.isExpired).toList();
        setState(() {
          _allEvents = _filterEventsByDistance(upcomingOfflineEvents);
          _showingCachedData = true;
        });
        if (_currentUser != null) {
          _generateRecommendations();
        } else {
          _sortEventsByDistance(upcomingOfflineEvents);
        }
        await _loadAttendanceCounts(upcomingOfflineEvents);
      }

      setState(() => _isRefreshing = false);
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh. Showing last available data.'),
          ),
        );
      }
      print('Background refresh failed: $e');
    }
  }

  Future<void> _loadUserData() async {
    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      final userData = await _authService.getUserData(userId);
      if (!mounted) return;
      setState(() {
        _currentUser = userData;
      });
    }
  }

  Future<void> _loadEvents() async {
    final events = await _firebaseService.getEvents();
    final upcomingEvents = events.where((e) => !e.isExpired).toList();
    await _cacheService.cacheEvents(upcomingEvents);
    if (!mounted) return;
    setState(() {
      _allEvents = _filterEventsByDistance(upcomingEvents);
      _showingCachedData = false;
    });
    if (_currentUser != null) {
      _generateRecommendations();
    } else {
      _sortEventsByDistance(upcomingEvents);
    }
    await _loadAttendanceCounts(upcomingEvents);
    _updateQuickStats();
  }

  Future<void> _loadAttendanceCounts(List<Event> events) async {
    final eventIds = events.map((event) => event.id).where((id) => id.isNotEmpty).toList();
    final counts = await _userService.getAttendanceCounts(eventIds);
    if (!mounted) return;
    setState(() {
      _attendanceCounts = counts;
    });
  }

  void _generateRecommendations() {
    if (_currentUser == null) return;

    final recommended = _recommendationService.getRecommendedEvents(
      allEvents: _allEvents,
      user: _currentUser!,
    );
    final trending = _recommendationService.getTrendingEvents(
      allEvents: _allEvents,
      limit: 5,
    );

    setState(() {
      _recommendedEvents = _filterEventsByDistance(recommended).take(10).toList();
      _trendingEvents = _filterEventsByDistance(trending);
      _nearbyEvents = _filterEventsByDistance(recommended);
    });
  }

  void _sortEventsByDistance(List<Event> events) {
    if (_locationService.currentPosition == null) {
      setState(() {
        _nearbyEvents = _filterEventsByDistance(events);
      });
      return;
    }

    final filteredEvents = _filterEventsByDistance(events);
    filteredEvents.sort((a, b) {
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

    setState(() {
      _nearbyEvents = filteredEvents;
    });
  }

  double? _getDistance(Event event) {
    return _locationService.getDistanceToPoint(event.latitude, event.longitude);
  }

  void _updateQuickStats() {
    if (_allEvents.isEmpty) return;
    final active = _allEvents.where((e) => !e.isExpired).length;
    final categoryCount = <String, int>{};
    for (final e in _allEvents) {
      categoryCount[e.category] = (categoryCount[e.category] ?? 0) + 1;
    }
    final top = categoryCount.isEmpty
        ? ''
        : categoryCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    if (mounted) {
      setState(() {
        _totalActiveEvents = active;
        _topCategory = top;
      });
    }
  }

  Future<void> _openCreateEventScreen() async {
    if (!mounted) return;

    if (!_authService.isLoggedIn()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create an event.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEventScreen(),
      ),
    );

    if (mounted) {
      await _refreshFromFirebase(showFeedback: false);
    }
  }

  Future<void> _forceRefresh() async {
    await _cacheService.clearEventsCache();
    await _loadUserData();
    await _refreshFromFirebase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aaspas'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh events',
            onPressed: _isRefreshing ? null : _forceRefresh,
          ),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
      body: _loadingLocation
          ? _buildLoadingState()
          : RefreshIndicator(
        onRefresh: _forceRefresh,
        child: _buildEventsList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateEventScreen,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      children: const [
        SizedBox(height: 16),
        EventListSkeleton(itemCount: 6),
      ],
    );
  }

  Widget _buildEventsList() {
    List<Event> displayEvents = _allEvents;
    if (_searchQuery.isNotEmpty) {
      displayEvents = _allEvents.where((event) {
        final query = _searchQuery.toLowerCase();
        return event.title.toLowerCase().contains(query) ||
            event.description.toLowerCase().contains(query) ||
            event.category.toLowerCase().contains(query) ||
            event.locationName.toLowerCase().contains(query);
      }).toList();
    }

    if (displayEvents.isEmpty && _searchQuery.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          const EmailVerificationBanner(),
          _buildCachedDataNotice(),
          _buildSearchBar(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: EmptyStateWidget(
              icon: Icons.search_off,
              title: 'No Results',
              message: 'No events match "$_searchQuery". Try a different search term.',
            ),
          ),
        ],
      );
    }

    if (_allEvents.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          const EmailVerificationBanner(),
          _buildCachedDataNotice(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: EmptyStateWidget(
              icon: Icons.event_busy,
              title: 'No Events Near You',
              message:
              'Be the first to create an event in your area and help build the community!',
              actionLabel: 'Create Event',
              onAction: _openCreateEventScreen,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        const EmailVerificationBanner(),
        _buildCachedDataNotice(),

        _buildSearchBar(),
        const SizedBox(height: 8),
        if (_searchQuery.isEmpty && _trendingEvents.isNotEmpty)
          _buildTrendingSection(),
        if (_searchQuery.isEmpty &&
            _currentUser != null &&
            _currentUser!.favoriteCategories.isNotEmpty)
          _buildRecommendedSection(),
        _buildAllEventsSection(displayEvents),
      ],
    );
  }

  Widget _buildCachedDataNotice() {
    if (!_showingCachedData) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 18, color: Colors.amber[800]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing cached events while fresh data loads.',
                style: TextStyle(
                  color: Colors.amber[900],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
          });
        },
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    if (_allEvents.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[700]!, Colors.indigo[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Aaspas in Numbers',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat(
                Icons.event_available,
                _totalActiveEvents.toString(),
                'Active Events',
              ),
              _buildQuickStatDivider(),
              _buildQuickStat(
                Icons.trending_up,
                _topCategory.isEmpty ? '-' : _topCategory,
                'Top Category',
              ),
              _buildQuickStatDivider(),
              _buildQuickStat(
                Icons.location_on,
                'Nepal',
                'Location',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white30,
    );
  }

  Widget _buildRecommendedSection() {
    if (_recommendedEvents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.orange[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Recommended for You',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Based on your interests: ${_currentUser!.favoriteCategories.join(", ")}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 235,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recommendedEvents.take(5).length,
            itemBuilder: (context, index) {
              final event = _recommendedEvents[index];
              final distance = _getDistance(event);
              final reasons = _recommendationService.getRecommendationReasons(
                event: event,
                user: _currentUser!,
              );
              final visibleReasons = reasons.take(2).toList();
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
                child: Container(
                  width: 210,
                  margin: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 90,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildSmartCardHeader(event),
                              if (index == 0)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[700],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star, color: Colors.white, size: 10),
                                        SizedBox(width: 2),
                                        Text(
                                          'Top Pick',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (visibleReasons.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 3,
                                    children: visibleReasons
                                        .map(
                                          (reason) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.orange[200]!,
                                          ),
                                        ),
                                        child: Text(
                                          reason,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.orange[900],
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                        .toList(),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                const Spacer(),
                                Row(
                                  children: [
                                    Icon(
                                      CategoryHelper.getIconForCategory(event.category),
                                      size: 12,
                                      color: CategoryHelper.getColorForCategory(event.category),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      event.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: CategoryHelper.getColorForCategory(event.category),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (distance != null)
                                      Text(
                                        '${distance.toStringAsFixed(1)}km',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
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
            },
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.red[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Trending Near You',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Most engaged events within 5km based on views, saves, attendance, and shares',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _trendingEvents.length,
            itemBuilder: (context, index) {
              final event = _trendingEvents[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
                child: Container(
                  width: 240,
                  margin: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildSmartCardHeader(event),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[700],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  event.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _buildTrendingStat(
                                      Icons.visibility_outlined,
                                      '${event.viewCount}',
                                    ),
                                    _buildTrendingStat(
                                      Icons.bookmark_outline,
                                      '${event.saveCount}',
                                    ),
                                    _buildTrendingStat(
                                      Icons.people_alt_outlined,
                                      '${event.attendingCount}',
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  event.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CategoryHelper.getColorForCategory(event.category),
                                    fontWeight: FontWeight.w600,
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
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTrendingStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.red[700]),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: Colors.red[800],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSmartCardHeader(Event event) {
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;

    if (hasImage) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              event.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildSmartCardFallback(event);
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildSmartCardFallback(event);
  }

  Widget _buildSmartCardFallback(Event event) {
    return Container(
      decoration: BoxDecoration(
        color: CategoryHelper.getLightColorForCategory(event.category),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Center(
        child: Icon(
          CategoryHelper.getIconForCategory(event.category),
          size: 46,
          color: CategoryHelper.getColorForCategory(event.category),
        ),
      ),
    );
  }

  Widget _buildAllEventsSection(List<Event> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _searchQuery.isNotEmpty
                    ? 'Search Results'
                    : (_currentUser != null &&
                    _currentUser!.favoriteCategories.isNotEmpty
                    ? 'All Events'
                    : 'Nearby Events'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${events.length} events${_searchQuery.isNotEmpty ? ' found' : ' within 5km'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        ...events.map((event) {
          return EventCard(
            event: event,
            distance: _getDistance(event),
            attendanceCount: _attendanceCounts[event.id] ?? 0,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailsScreen(event: event),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}