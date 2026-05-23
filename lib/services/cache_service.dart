import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_model.dart';
import '../models/user_model.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _eventsKey = 'cached_events';
  static const String _eventsTimestampKey = 'cached_events_timestamp';
  static const String _userKey = 'cached_user_';
  static const String _userTimestampKey = 'cached_user_timestamp_';

  static const int _cacheExpiryMinutes = 5;

  Future<void> cacheEvents(List<Event> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = events.map((e) => e.toMap()).toList();
      await prefs.setString(_eventsKey, jsonEncode(eventsJson));
      await prefs.setInt(
        _eventsTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('Cached ${events.length} events');
    } catch (e) {
      print('Error caching events: $e');
    }
  }

  Future<List<Event>?> getCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsString = prefs.getString(_eventsKey);
      if (eventsString == null) return null;

      if (_isCacheExpired(prefs, _eventsTimestampKey)) {
        print('Events cache expired');
        return null;
      }

      final List<dynamic> eventsJson = jsonDecode(eventsString);
      final events = eventsJson
          .map((e) => Event.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      print('Loaded ${events.length} events from cache');
      return events;
    } catch (e) {
      print('Error reading events cache: $e');
      return null;
    }
  }

  Future<bool> hasAnyEventCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_eventsKey) != null;
  }

  Future<List<Event>?> getCachedEventsOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsString = prefs.getString(_eventsKey);
      if (eventsString == null) return null;

      final List<dynamic> eventsJson = jsonDecode(eventsString);
      final events = eventsJson
          .map((e) => Event.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      print('Loaded ${events.length} events from offline cache');
      return events;
    } catch (e) {
      print('Error reading offline cache: $e');
      return null;
    }
  }

  Future<void> cacheUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey + user.id, jsonEncode(user.toMap()));
      await prefs.setInt(
        _userTimestampKey + user.id,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('Cached user: ${user.username}');
    } catch (e) {
      print('Error caching user: $e');
    }
  }

  Future<User?> getCachedUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString(_userKey + userId);
      if (userString == null) return null;

      if (_isCacheExpired(prefs, _userTimestampKey + userId)) {
        print('User cache expired');
        return null;
      }

      final user = User.fromMap(
        Map<String, dynamic>.from(jsonDecode(userString)),
      );
      print('Loaded user from cache: ${user.username}');
      return user;
    } catch (e) {
      print('Error reading user cache: $e');
      return null;
    }
  }

  Future<User?> getCachedUserOffline(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString(_userKey + userId);
      if (userString == null) return null;

      return User.fromMap(
        Map<String, dynamic>.from(jsonDecode(userString)),
      );
    } catch (e) {
      print('Error reading offline user cache: $e');
      return null;
    }
  }

  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventsKey);
      await prefs.remove(_eventsTimestampKey);
      print('All cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  Future<void> clearEventsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventsKey);
      await prefs.remove(_eventsTimestampKey);
      print('Events cache cleared');
    } catch (e) {
      print('Error clearing events cache: $e');
    }
  }

  Future<void> clearUserCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey + userId);
      await prefs.remove(_userTimestampKey + userId);
      print('User cache cleared');
    } catch (e) {
      print('Error clearing user cache: $e');
    }
  }

  Future<void> clearUsersCache(List<String> userIds) async {
    for (final userId in userIds) {
      await clearUserCache(userId);
    }
  }

  bool _isCacheExpired(SharedPreferences prefs, String timestampKey) {
    final timestamp = prefs.getInt(timestampKey);
    if (timestamp == null) return true;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final expiryTime = cacheTime.add(
      const Duration(minutes: _cacheExpiryMinutes),
    );

    return DateTime.now().isAfter(expiryTime);
  }

  Future<int?> getCacheAgeMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_eventsTimestampKey);
      if (timestamp == null) return null;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime).inMinutes;
    } catch (e) {
      return null;
    }
  }
}
