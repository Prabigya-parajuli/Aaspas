import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/event_model.dart';
import '../../services/analytics_service.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  final List<Event> events;

  const AnalyticsDashboardScreen({
    Key? key,
    required this.events,
  }) : super(key: key);

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  late Future<AnalyticsData> _analyticsFuture;
  final AnalyticsService _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _analyticsService.getAnalytics(widget.events);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.red[700],
        elevation: 0,
      ),
      body: FutureBuilder<AnalyticsData>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading analytics: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _analyticsFuture = _analyticsService.getAnalytics(widget.events);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final analytics = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Cards Row
                _buildKPICards(analytics),
                const SizedBox(height: 24),

                // Top Category Card
                _buildTopCategoryCard(analytics),
                const SizedBox(height: 24),

                // Category Breakdown Chart
                _buildCategoryChartCard(analytics),
                const SizedBox(height: 24),

                // Top Viewed Events
                _buildTopEventsCard(
                  title: 'Most Viewed Events',
                  events: analytics.topViewedEvents,
                  metric: (e) => '${e.viewCount} views',
                ),
                const SizedBox(height: 16),

                // Top Attended Events
                _buildTopEventsCard(
                  title: 'Most Attended Events',
                  events: analytics.topAttendedEvents,
                  metric: (e) => '${e.attendingCount} attending',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKPICards(AnalyticsData analytics) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildKPIcard(
          title: 'Total Events',
          value: analytics.totalEvents.toString(),
          icon: Icons.event,
          color: Colors.blue,
        ),
        _buildKPIcard(
          title: 'Active Events',
          value: analytics.activeEvents.toString(),
          icon: Icons.event_available,
          color: Colors.green,
        ),
        _buildKPIcard(
          title: 'Expired Events',
          value: analytics.expiredEvents.toString(),
          icon: Icons.event_busy,
          color: Colors.orange,
        ),
        _buildKPIcard(
          title: 'Events This Week',
          value: analytics.eventsThisWeek.toString(),
          icon: Icons.calendar_today,
          color: Colors.purple,
        ),
        _buildKPIcard(
          title: 'Total Users',
          value: analytics.totalUsers.toString(),
          icon: Icons.people,
          color: Colors.teal,
        ),
        _buildKPIcard(
          title: 'Total Views',
          value: analytics.totalViews.toString(),
          icon: Icons.visibility,
          color: Colors.indigo,
        ),
        _buildKPIcard(
          title: 'Total Attendances',
          value: analytics.totalAttendances.toString(),
          icon: Icons.check_circle,
          color: Colors.deepOrange,
        ),
      ],
    );
  }

  Widget _buildKPIcard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),  // Reduced from 12 to 8
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),  // Reduced from 28 to 24
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,  // Reduced from 24 to 18
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,  // Reduced from 12 to 10
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategoryCard(AnalyticsData analytics) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Top Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, size: 32, color: Colors.amber),
                  const SizedBox(width: 12),
                  Text(
                    analytics.topCategory,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
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

  Widget _buildCategoryChartCard(AnalyticsData analytics) {
    if (analytics.categoryBreakdown.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No category data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    // Prepare data for chart
    final entries = analytics.categoryBreakdown.entries.toList();
    final total = analytics.totalEvents;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Events by Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b)).toDouble(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < entries.length) {
                            return Text(
                              entries[index].key,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend - show percentages
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: entries.map((entry) {
                final percentage = (entry.value / total * 100).toStringAsFixed(1);
                return Chip(
                  label: Text('${entry.key}: $percentage%'),
                  backgroundColor: Colors.blue[50],
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEventsCard({
    required String title,
    required List<Event> events,
    required String Function(Event) metric,
  }) {
    if (events.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No events available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final event = events[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(event.category),
                  trailing: Text(
                    metric(event),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    // Navigate to event details
                    Navigator.pushNamed(
                      context,
                      '/event-details',
                      arguments: event,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}