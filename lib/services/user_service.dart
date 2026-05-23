import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> saveEvent(String userId, String eventId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'savedEventIds': FieldValue.arrayUnion([eventId]),
        'eventsSaved': FieldValue.increment(1),
      });
      print('Event saved: $eventId for user $userId');
      return true;
    } catch (e) {
      print('Error saving event: $e');
      return false;
    }
  }

  Future<bool> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
      return true;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }

  Future<bool> unsaveEvent(String userId, String eventId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'savedEventIds': FieldValue.arrayRemove([eventId]),
        'eventsSaved': FieldValue.increment(-1),
      });
      print('Event unsaved: $eventId for user $userId');
      return true;
    } catch (e) {
      print('Error unsaving event: $e');
      return false;
    }
  }

  Future<bool> isEventSaved(String userId, String eventId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final savedIds = List<String>.from(doc.data()?['savedEventIds'] ?? []);
        return savedIds.contains(eventId);
      }
      return false;
    } catch (e) {
      print('Error checking saved status: $e');
      return false;
    }
  }

  Future<List<String>> getSavedEventIds(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return List<String>.from(doc.data()?['savedEventIds'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting saved events: $e');
      return [];
    }
  }

  Future<bool> markAttending(String userId, String eventId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'attendingEventIds': FieldValue.arrayUnion([eventId]),
        'eventsAttended': FieldValue.increment(1),
      });
      print('Marked attending: $eventId for user $userId');
      return true;
    } catch (e) {
      print('Error marking attending: $e');
      return false;
    }
  }

  Future<bool> unmarkAttending(String userId, String eventId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'attendingEventIds': FieldValue.arrayRemove([eventId]),
        'eventsAttended': FieldValue.increment(-1),
      });
      print('Unmarked attending: $eventId for user $userId');
      return true;
    } catch (e) {
      print('Error unmarking attending: $e');
      return false;
    }
  }

  Future<bool> isAttending(String userId, String eventId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final attendingIds =
            List<String>.from(doc.data()?['attendingEventIds'] ?? []);
        return attendingIds.contains(eventId);
      }
      return false;
    } catch (e) {
      print('Error checking attending: $e');
      return false;
    }
  }

  Future<List<String>> getAttendingEventIds(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return List<String>.from(doc.data()?['attendingEventIds'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting attending events: $e');
      return [];
    }
  }

  Future<bool> updateFavoriteCategories(
    String userId,
    List<String> categories,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'favoriteCategories': categories,
      });
      print('Favorite categories updated for user $userId');
      return true;
    } catch (e) {
      print('Error updating favorite categories: $e');
      return false;
    }
  }

  Future<List<String>> getFavoriteCategories(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return List<String>.from(doc.data()?['favoriteCategories'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting favorite categories: $e');
      return [];
    }
  }

  Future<bool> incrementEventsCreated(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'eventsCreated': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      print('Error incrementing events created: $e');
      return false;
    }
  }

  Future<bool> decrementEventsCreated(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'eventsCreated': FieldValue.increment(-1),
      });
      return true;
    } catch (e) {
      print('Error decrementing events created: $e');
      return false;
    }
  }

  Future<Map<String, int>> getAttendanceCounts(List<String> eventIds) async {
    try {
      if (eventIds.isEmpty) return {};

      final counts = <String, int>{
        for (final eventId in eventIds) eventId: 0,
      };

      for (int i = 0; i < eventIds.length; i += 10) {
        final batch = eventIds.skip(i).take(10).toList();
        final querySnapshot = await _firestore
            .collection('users')
            .where('attendingEventIds', arrayContainsAny: batch)
            .get();

        for (final doc in querySnapshot.docs) {
          final attendingIds =
              List<String>.from(doc.data()['attendingEventIds'] ?? []);
          for (final attendingId in attendingIds) {
            if (counts.containsKey(attendingId)) {
              counts[attendingId] = counts[attendingId]! + 1;
            }
          }
        }
      }

      return counts;
    } catch (e) {
      print('Error getting attendance counts: $e');
      return {for (final eventId in eventIds) eventId: 0};
    }
  }

  Future<User?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return User.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
}
