import 'package:flutter_test/flutter_test.dart';
import 'package:aaspas/services/location_service.dart';

void main() {
  group('LocationService - Distance Calculation', () {
    final locationService = LocationService();

    test('Distance between same point should be 0', () {
      double distance = locationService.calculateDistance(
        27.7, 85.3,
        27.7, 85.3,
      );
      expect(distance, equals(0));
    });

    test('Distance between Kathmandu and Pokhara should be approximately 142km', () {
      double distance = locationService.calculateDistance(
        27.7172, 85.3240,  // Kathmandu
        28.2096, 83.9856,  // Pokhara
      );
      expect(distance, closeTo(142.4, 5)); // Within 5km margin
    });

    test('Distance calculation should return positive value for different points', () {
      double distance = locationService.calculateDistance(
        27.7, 85.3,
        27.8, 85.4,
      );
      expect(distance, greaterThan(0));
    });
  });
}