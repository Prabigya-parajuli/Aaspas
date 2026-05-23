import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class AnalyticsData {
  final int totalEvents;
  final int activeEvents;
  final int expiredEvents;
  final int eventsThisWeek;
  final int totalUsers;
  final int totalAttendances;
  final int totalViews;
  final Map<String, int> categoryBreakdown;
  final List<Event> topViewedEvents;
  final List<Event> topAttendedEvents;
  final String topCategory;

  AnalyticsData({
    required this.totalEvents,
    required this.activeEvents,
    required this.expiredEvents,
    required this.eventsThisWeek,
    required this.totalUsers,
    required this.totalAttendances,
    required this.totalViews,
    required this.categoryBreakdown,
    required this.topViewedEvents,
    required this.topAttendedEvents,
    required this.topCategory,
  });
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AnalyticsData> getAnalytics(List<Event> allEvents) async {
    // Basic event stats
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final activeEvents = allEvents.where((e) => !e.isExpired).toList();
    final expiredEvents = allEvents.where((e) => e.isExpired).toList();
    final eventsThisWeek = allEvents
        .where((e) => e.createdAt.isAfter(weekAgo))
        .length;

    // Category breakdown
    final categoryBreakdown = <String, int>{};
    for (final event in allEvents) {
      categoryBreakdown[event.category] =
          (categoryBreakdown[event.category] ?? 0) + 1;
    }

    // Top category
    String topCategory = 'None';
    if (categoryBreakdown.isNotEmpty) {
      topCategory = categoryBreakdown.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Top viewed events
    final topViewed = List<Event>.from(allEvents)
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

    // Top attended events
    final topAttended = List<Event>.from(allEvents)
      ..sort((a, b) => b.attendingCount.compareTo(a.attendingCount));

    // Total stats
    final totalViews = allEvents.fold(0, (sum, e) => sum + e.viewCount);
    final totalAttendances =
    allEvents.fold(0, (sum, e) => sum + e.attendingCount);

    // Total users from Firestore
    int totalUsers = 0;
    try {
      final usersSnapshot = await _firestore.collection('users').count().get();
      totalUsers = usersSnapshot.count ?? 0;
    } catch (e) {
      totalUsers = 0;
    }

    return AnalyticsData(
      totalEvents: allEvents.length,
      activeEvents: activeEvents.length,
      expiredEvents: expiredEvents.length,
      eventsThisWeek: eventsThisWeek,
      totalUsers: totalUsers,
      totalAttendances: totalAttendances,
      totalViews: totalViews,
      categoryBreakdown: categoryBreakdown,
      topViewedEvents: topViewed.take(5).toList(),
      topAttendedEvents: topAttended.take(5).toList(),
      topCategory: topCategory,
    );
  }
}