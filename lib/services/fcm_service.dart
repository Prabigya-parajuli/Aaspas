import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();

  factory FCMService() => _instance;

  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    _fcmToken = await _messaging.getToken();
    debugPrint('FCM token: $_fcmToken');

    _messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      debugPrint('FCM token refreshed');

      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await saveTokenToFirestore(userId);
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Foreground FCM message: ${message.notification?.title}');
      _showBanner(
        title: message.notification?.title ?? 'New Notification',
        body: message.notification?.body ?? '',
      );
    });

    debugPrint('FCM initialized successfully');
  }

  Future<void> saveTokenToFirestore(String userId) async {
    _fcmToken ??= await _messaging.getToken();
    if (_fcmToken == null) {
      debugPrint('No FCM token available to save');
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': _fcmToken,
        'tokenUpdatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      debugPrint('FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> checkAndShowPendingNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('targetUserId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('No pending notifications for user: $userId');
        return;
      }

      debugPrint('Found ${snapshot.docs.length} pending notifications');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        _showBanner(
          title: data['title'] ?? 'New Notification',
          body: data['body'] ?? '',
        );
        await doc.reference.update({'read': true});
        await Future.delayed(const Duration(milliseconds: 400));
      }
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }

  Future<void> sendNotificationToUser({
    String? targetUserId,
    required String targetToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final resolvedUserId = targetUserId ?? _auth.currentUser?.uid;
      if (resolvedUserId == null) {
        debugPrint('Cannot queue notification without a target user');
        return;
      }

      await _firestore.collection('notifications').add({
        'targetUserId': resolvedUserId,
        'targetToken': targetToken,
        'title': title,
        'body': body,
        'data': data ?? <String, String>{},
        'createdAt': DateTime.now().toIso8601String(),
        'read': false,
      });
      debugPrint('Notification queued for user: $resolvedUserId');
    } catch (e) {
      debugPrint('Error queuing notification: $e');
    }
  }

  Future<void> notifyNearbyUsersOfNewEvent({
    required String eventTitle,
    required String eventCategory,
    required String eventId,
    required double eventLat,
    required double eventLng,
  }) async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('favoriteCategories', arrayContains: eventCategory)
          .get();

      debugPrint(
        'Notifying ${usersSnapshot.docs.length} users about new $eventCategory event',
      );

      for (final userDoc in usersSnapshot.docs) {
        final token = userDoc.data()['fcmToken'] as String?;
        if (token == null || token == _fcmToken) {
          continue;
        }

        await sendNotificationToUser(
          targetUserId: userDoc.id,
          targetToken: token,
          title: 'New $eventCategory Event!',
          body: eventTitle,
          data: {'eventId': eventId, 'type': 'new_event'},
        );
      }

      debugPrint('Nearby user notifications queued successfully');
    } catch (e) {
      debugPrint('Error notifying nearby users: $e');
    }
  }

  void _showBanner({required String title, required String body}) {
    Future.delayed(const Duration(milliseconds: 300), () {
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue[800],
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
  }
}
