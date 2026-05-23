class Event {
  final String id;
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final DateTime dateTime;
  final String locationName;
  final String? areaName;
  final String? imageUrl;
  final String submittedBy;
  final DateTime createdAt;
  final int viewCount;
  final int saveCount;
  final int shareCount;
  final int attendingCount;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.dateTime,
    required this.locationName,
    this.areaName,
    this.imageUrl,
    required this.submittedBy,
    required this.createdAt,
    this.viewCount = 0,
    this.saveCount = 0,
    this.shareCount = 0,
    this.attendingCount = 0,
  });

  bool get isExpired => dateTime.isBefore(DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'dateTime': dateTime.toIso8601String(),
      'locationName': locationName,
      'areaName': areaName,
      'imageUrl': imageUrl,
      'submittedBy': submittedBy,
      'createdAt': createdAt.toIso8601String(),
      'viewCount': viewCount,
      'saveCount': saveCount,
      'shareCount': shareCount,
      'attendingCount': attendingCount,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      dateTime: DateTime.parse(
          map['dateTime'] ?? DateTime.now().toIso8601String()),
      locationName: map['locationName'] ?? '',
      areaName: map['areaName'],
      imageUrl: map['imageUrl'],
      submittedBy: map['submittedBy'] ?? '',
      createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String()),
      viewCount: (map['viewCount'] ?? 0) as int,
      saveCount: (map['saveCount'] ?? 0) as int,
      shareCount: (map['shareCount'] ?? 0) as int,
      attendingCount: (map['attendingCount'] ?? 0) as int,
    );
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? latitude,
    double? longitude,
    DateTime? dateTime,
    String? locationName,
    String? areaName,
    String? imageUrl,
    String? submittedBy,
    DateTime? createdAt,
    int? viewCount,
    int? saveCount,
    int? shareCount,
    int? attendingCount,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dateTime: dateTime ?? this.dateTime,
      locationName: locationName ?? this.locationName,
      areaName: areaName ?? this.areaName,
      imageUrl: imageUrl ?? this.imageUrl,
      submittedBy: submittedBy ?? this.submittedBy,
      createdAt: createdAt ?? this.createdAt,
      viewCount: viewCount ?? this.viewCount,
      saveCount: saveCount ?? this.saveCount,
      shareCount: shareCount ?? this.shareCount,
      attendingCount: attendingCount ?? this.attendingCount,
    );
  }
}