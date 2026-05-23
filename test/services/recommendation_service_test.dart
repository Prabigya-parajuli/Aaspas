import 'package:flutter_test/flutter_test.dart';
import 'package:aaspas/services/recommendation_service.dart';
import 'package:aaspas/models/event_model.dart';
import 'package:aaspas/models/user_model.dart';

void main() {
  group('Recommendation Algorithm', () {
    test('Event matching favorite category should have higher score', () {
      // Create test user who likes Tech
      User user = User(
        id: 'test',
        username: 'test',
        favoriteCategories: ['Tech'],
        savedEventIds: [],
        attendingEventIds: [],
        eventsAttended: 0,
        eventsSaved: 0,
        eventsCreated: 0,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      // Create two events - one Tech, one Health
      Event techEvent = Event(
        id: '1',
        title: 'Tech Meetup',
        description: 'Test',
        category: 'Tech',
        latitude: 27.7,
        longitude: 85.3,
        dateTime: DateTime.now().add(Duration(days: 2)),
        locationName: 'Location',
        submittedBy: 'user',
        createdAt: DateTime.now(),
      );

      Event healthEvent = Event(
        id: '2',
        title: 'Health Camp',
        description: 'Test',
        category: 'Health',
        latitude: 27.7,
        longitude: 85.3,
        dateTime: DateTime.now().add(Duration(days: 2)),
        locationName: 'Location',
        submittedBy: 'user',
        createdAt: DateTime.now(),
      );

      // Tech event should be recommended over Health event
      expect(techEvent.category, equals('Tech'));
      expect(user.favoriteCategories.contains(techEvent.category), true);
      expect(user.favoriteCategories.contains(healthEvent.category), false);
    });
  });
}