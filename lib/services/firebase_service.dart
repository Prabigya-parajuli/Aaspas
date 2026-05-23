import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../models/event_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _eventsCollection = 'events';

  Future<String?> addEvent(Event event) async {
    try {
      print('Adding event: ${event.title}');
      final docRef = _firestore.collection(_eventsCollection).doc();
      final eventData = event.copyWith(id: docRef.id).toMap();

      await docRef.set(eventData).timeout(const Duration(seconds: 15));

      print('Event added with ID: ${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e) {
      print('Firestore addEvent error [${e.code}]: ${e.message}');
      return null;
    } on TimeoutException catch (e) {
      print('Firestore addEvent timeout: $e');
      return null;
    } catch (e) {
      print('Error adding event: $e');
      return null;
    }
  }

  Future<List<Event>> getEvents() async {
    try {
      final querySnapshot = await _firestore
          .collection(_eventsCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Event.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting events: $e');
      return [];
    }
  }

  Future<List<Event>> getEventsByUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_eventsCollection)
          .where('submittedBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Event.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting events by user: $e');
      return [];
    }
  }

  Future<List<Event>> getEventsByIds(List<String> eventIds) async {
    try {
      if (eventIds.isEmpty) return [];

      final List<Event> allEvents = [];

      for (int i = 0; i < eventIds.length; i += 10) {
        final batch = eventIds.skip(i).take(10).toList();
        final querySnapshot = await _firestore
            .collection(_eventsCollection)
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final events = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Event.fromMap(data);
        }).toList();

        allEvents.addAll(events);
      }

      return allEvents;
    } catch (e) {
      print('Error getting events by IDs: $e');
      return [];
    }
  }

  Stream<List<Event>> getEventsStream() {
    return _firestore
        .collection(_eventsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Event.fromMap(data);
      }).toList();
    });
  }

  Future<Event?> getEventById(String id) async {
    try {
      final doc = await _firestore.collection(_eventsCollection).doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return Event.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting event: $e');
      return null;
    }
  }

  Future<bool> updateEvent(String id, Event event) async {
    try {
      await _firestore.collection(_eventsCollection).doc(id).update(
        event.toMap(),
      );
      return true;
    } catch (e) {
      print('Error updating event: $e');
      return false;
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      await _firestore.collection(_eventsCollection).doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  Future<List<Event>> getEventsByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection(_eventsCollection)
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Event.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting events by category: $e');
      return [];
    }
  }

  Future<List<Event>> getEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_eventsCollection)
          .where(
            'dateTime',
            isGreaterThanOrEqualTo: startDate.toIso8601String(),
          )
          .where(
            'dateTime',
            isLessThanOrEqualTo: endDate.toIso8601String(),
          )
          .orderBy('dateTime')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Event.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting events by date range: $e');
      return [];
    }
  }

  Future<void> reportEvent({
    required String eventId,
    required String reportedBy,
    required String reason,
    required String eventTitle,
  }) async {
    await _firestore.collection('reports').add({
      'eventId': eventId,
      'eventTitle': eventTitle,
      'reportedBy': reportedBy,
      'reason': reason,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
    debugPrint('✅ Report submitted for event: $eventId');
  }

  Future<bool> incrementViewCount(String eventId) async {
    return _incrementCounter(eventId, 'viewCount');
  }

  Future<bool> incrementSaveCount(String eventId) async {
    return _incrementCounter(eventId, 'saveCount');
  }

  Future<bool> decrementSaveCount(String eventId) async {
    return _incrementCounter(eventId, 'saveCount', amount: -1);
  }

  Future<bool> incrementAttendingCount(String eventId) async {
    return _incrementCounter(eventId, 'attendingCount');
  }

  Future<bool> decrementAttendingCount(String eventId) async {
    return _incrementCounter(eventId, 'attendingCount', amount: -1);
  }

  Future<bool> incrementShareCount(String eventId) async {
    return _incrementCounter(eventId, 'shareCount');
  }

  Future<bool> _incrementCounter(
    String eventId,
    String field, {
    int amount = 1,
  }) async {
    try {
      await _firestore.collection(_eventsCollection).doc(eventId).update({
        field: FieldValue.increment(amount),
      });
      return true;
    } catch (e) {
      print('Error updating $field for $eventId: $e');
      return false;
    }
  }
}
