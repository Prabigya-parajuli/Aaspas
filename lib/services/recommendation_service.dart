import '../models/event_model.dart';
import '../models/user_model.dart';
import 'location_service.dart';

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();

  factory RecommendationService() {
    return _instance;
  }

  RecommendationService._internal();

  final LocationService _locationService = LocationService();

  List<Event> getRecommendedEvents({
    required List<Event> allEvents,
    required User user,
  }) {
    final scoredEvents = allEvents.map((event) {
      final score = _calculateEventScore(event, user);
      return _ScoredEvent(event: event, score: score);
    }).toList();

    scoredEvents.sort((a, b) => b.score.compareTo(a.score));
    return scoredEvents.map((se) => se.event).toList();
  }

  List<Event> getTrendingEvents({
    required List<Event> allEvents,
    int limit = 5,
  }) {
    final scoredEvents = allEvents.map((event) {
      final score = _calculateTrendingScore(event);
      return _ScoredEvent(event: event, score: score);
    }).toList();

    scoredEvents.sort((a, b) => b.score.compareTo(a.score));
    return scoredEvents.take(limit).map((se) => se.event).toList();
  }

  List<String> getRecommendationReasons({
    required Event event,
    required User user,
  }) {
    final reasons = <String>[];
    final distance = _locationService.getDistanceToPoint(
      event.latitude,
      event.longitude,
    );

    if (user.favoriteCategories.contains(event.category)) {
      reasons.add('Matches your favorite category');
    }

    if (_userHasSavedCategory(event.category, user)) {
      reasons.add('Similar to events you saved');
    }

    if (distance != null && distance < 5) {
      reasons.add('Close to your location');
    }

    if (_calculateTrendingScore(event) >= 20) {
      reasons.add('Popular this week');
    }

    final daysSinceCreation = DateTime.now().difference(event.createdAt).inDays;
    if (daysSinceCreation < 3) {
      reasons.add('Recently added');
    }

    return reasons.take(2).toList();
  }

  int _calculateEventScore(Event event, User user) {
    int score = 0;

    if (user.favoriteCategories.contains(event.category)) {
      score += 50;
    }

    if (_userHasSavedCategory(event.category, user)) {
      score += 30;
    }

    final distance = _locationService.getDistanceToPoint(
      event.latitude,
      event.longitude,
    );
    if (distance != null) {
      if (distance < 2) {
        score += 30;
      } else if (distance < 5) {
        score += 20;
      } else if (distance < 10) {
        score += 10;
      }
    }

    final daysSinceCreation = DateTime.now().difference(event.createdAt).inDays;
    if (daysSinceCreation < 1) {
      score += 15;
    } else if (daysSinceCreation < 3) {
      score += 10;
    } else if (daysSinceCreation < 7) {
      score += 5;
    }

    final daysUntilEvent = event.dateTime.difference(DateTime.now()).inDays;
    if (daysUntilEvent >= 0 && daysUntilEvent <= 3) {
      score += 15;
    } else if (daysUntilEvent > 3 && daysUntilEvent <= 7) {
      score += 10;
    }

    return score;
  }

  int _calculateTrendingScore(Event event) {
    final daysSinceCreation = DateTime.now().difference(event.createdAt).inDays;
    final recencyBonus = daysSinceCreation < 1
        ? 12
        : daysSinceCreation < 3
            ? 8
            : daysSinceCreation < 7
                ? 4
                : 0;

    return (event.attendingCount * 4) +
        (event.saveCount * 3) +
        (event.viewCount * 2) +
        (event.shareCount * 3) +
        recencyBonus;
  }

  bool _userHasSavedCategory(String category, User user) {
    return user.favoriteCategories.contains(category) && user.eventsSaved > 0;
  }

  List<Event> getTopRecommendations({
    required List<Event> allEvents,
    required User user,
    int limit = 5,
  }) {
    final recommended = getRecommendedEvents(
      allEvents: allEvents,
      user: user,
    );

    return recommended.take(limit).toList();
  }

  List<Event> getRecommendedByCategory({
    required List<Event> allEvents,
    required User user,
    required String category,
  }) {
    final categoryEvents = allEvents
        .where((event) => event.category == category)
        .toList();

    return getRecommendedEvents(
      allEvents: categoryEvents,
      user: user,
    );
  }

  List<Event> getRecommendedExcludingOwn({
    required List<Event> allEvents,
    required User user,
  }) {
    final otherEvents = allEvents
        .where((event) => event.submittedBy != user.id)
        .toList();

    return getRecommendedEvents(
      allEvents: otherEvents,
      user: user,
    );
  }

  List<Event> getSimilarEvents({
    required Event baseEvent,
    required List<Event> allEvents,
    int limit = 5,
  }) {
    final similarEvents = allEvents
        .where((e) => e.id != baseEvent.id && e.category == baseEvent.category)
        .toList();

    similarEvents.sort((a, b) {
      final distA = _calculateDistance(
        a.latitude,
        a.longitude,
        baseEvent.latitude,
        baseEvent.longitude,
      );
      final distB = _calculateDistance(
        b.latitude,
        b.longitude,
        baseEvent.latitude,
        baseEvent.longitude,
      );
      return distA.compareTo(distB);
    });

    return similarEvents.take(limit).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return (dLat * dLat + dLon * dLon);
  }
}

class _ScoredEvent {
  final Event event;
  final int score;

  _ScoredEvent({required this.event, required this.score});
}
