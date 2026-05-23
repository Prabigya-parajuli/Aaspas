import 'package:flutter_test/flutter_test.dart';
import 'package:aaspas/models/event_model.dart';

void main() {
  group('Event Model', () {
    test('Event should be expired if dateTime is in past', () {
      Event pastEvent = Event(
        id: '1',
        title: 'Past Event',
        description: 'Test',
        category: 'Tech',
        latitude: 27.7,
        longitude: 85.3,
        dateTime: DateTime.now().subtract(Duration(days: 1)),
        locationName: 'Location',
        submittedBy: 'user',
        createdAt: DateTime.now(),
      );
      expect(pastEvent.isExpired, true);
    });

    test('Event should not be expired if dateTime is in future', () {
      Event futureEvent = Event(
        id: '1',
        title: 'Future Event',
        description: 'Test',
        category: 'Tech',
        latitude: 27.7,
        longitude: 85.3,
        dateTime: DateTime.now().add(Duration(days: 1)),
        locationName: 'Location',
        submittedBy: 'user',
        createdAt: DateTime.now(),
      );
      expect(futureEvent.isExpired, false);
    });
  });
}