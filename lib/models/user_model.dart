class User {
  final String id;
  final String username;
  final String? email;
  final String? photoURL;
  final List<String> favoriteCategories;
  final List<String> savedEventIds;
  final List<String> attendingEventIds;
  final int eventsAttended;
  final int eventsSaved;
  final int eventsCreated;
  final DateTime createdAt;
  final DateTime lastLogin;

  User({
    required this.id,
    required this.username,
    this.email,
    this.photoURL,
    this.favoriteCategories = const [],
    this.savedEventIds = const [],
    this.attendingEventIds = const [],
    this.eventsAttended = 0,
    this.eventsSaved = 0,
    this.eventsCreated = 0,
    required this.createdAt,
    required this.lastLogin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'photoURL': photoURL,
      'favoriteCategories': favoriteCategories,
      'savedEventIds': savedEventIds,
      'attendingEventIds': attendingEventIds,
      'eventsAttended': eventsAttended,
      'eventsSaved': eventsSaved,
      'eventsCreated': eventsCreated,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      username: map['username'] ?? 'Anonymous',
      email: map['email'],
      photoURL: map['photoURL'],
      favoriteCategories: List<String>.from(map['favoriteCategories'] ?? []),
      savedEventIds: List<String>.from(map['savedEventIds'] ?? []),
      attendingEventIds: List<String>.from(map['attendingEventIds'] ?? []),
      eventsAttended: map['eventsAttended'] ?? 0,
      eventsSaved: map['eventsSaved'] ?? 0,
      eventsCreated: map['eventsCreated'] ?? 0,
      createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastLogin: DateTime.parse(
          map['lastLogin'] ?? DateTime.now().toIso8601String()),
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? photoURL,
    List<String>? favoriteCategories,
    List<String>? savedEventIds,
    List<String>? attendingEventIds,
    int? eventsAttended,
    int? eventsSaved,
    int? eventsCreated,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      savedEventIds: savedEventIds ?? this.savedEventIds,
      attendingEventIds: attendingEventIds ?? this.attendingEventIds,
      eventsAttended: eventsAttended ?? this.eventsAttended,
      eventsSaved: eventsSaved ?? this.eventsSaved,
      eventsCreated: eventsCreated ?? this.eventsCreated,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}