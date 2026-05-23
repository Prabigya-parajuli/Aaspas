import 'package:uuid/uuid.dart';
import '../models/event_model.dart';

class EventService {
  static final EventService _instance = EventService._internal();

  factory EventService() {
    return _instance;
  }

  EventService._internal();

  // Dummy events list (will be replaced with Firebase later)
  final List<Event> _events = [
    Event(
      id: '1',
      title: 'Blood Donation Drive',
      description: 'Annual blood donation camp at Kathmandu Medical College',
      category: 'Health',
      latitude: 27.7172,
      longitude: 85.3240,
      dateTime: DateTime.now().add(const Duration(days: 1)),
      locationName: 'Kathmandu Medical College',
      imageUrl: 'https://via.placeholder.com/300x200?text=Blood+Drive',
      submittedBy: 'admin',
      createdAt: DateTime.now(),
    ),
    Event(
      id: '2',
      title: 'Tech Workshop: Flutter Basics',
      description: 'Learn Flutter development from scratch with hands-on exercises',
      category: 'Tech',
      latitude: 27.7209,
      longitude: 85.3247,
      dateTime: DateTime.now().add(const Duration(days: 2)),
      locationName: 'Tech Hub Kathmandu',
      imageUrl: 'https://via.placeholder.com/300x200?text=Flutter+Workshop',
      submittedBy: 'admin',
      createdAt: DateTime.now(),
    ),
    Event(
      id: '3',
      title: 'Open Mic Night',
      description: 'Local poetry and music showcase featuring local artists',
      category: 'Culture',
      latitude: 27.7158,
      longitude: 85.3200,
      dateTime: DateTime.now().add(const Duration(days: 3)),
      locationName: 'Rani Pokhari',
      imageUrl: 'https://via.placeholder.com/300x200?text=Open+Mic',
      submittedBy: 'admin',
      createdAt: DateTime.now(),
    ),
    Event(
      id: '4',
      title: 'Basketball Tournament',
      description: 'Inter-college basketball championship with exciting matches',
      category: 'Sports',
      latitude: 27.7190,
      longitude: 85.3210,
      dateTime: DateTime.now().add(const Duration(days: 4)),
      locationName: 'Valley Sports Complex',
      imageUrl: 'https://via.placeholder.com/300x200?text=Basketball',
      submittedBy: 'admin',
      createdAt: DateTime.now(),
    ),
    Event(
      id: '5',
      title: 'Environmental Cleanup',
      description: 'Join us in cleaning up Rani Pokhari area and surrounding streets',
      category: 'Volunteer',
      latitude: 27.7180,
      longitude: 85.3220,
      dateTime: DateTime.now().add(const Duration(days: 5)),
      locationName: 'Rani Pokhari Area',
      imageUrl: 'https://via.placeholder.com/300x200?text=Cleanup',
      submittedBy: 'admin',
      createdAt: DateTime.now(),
    ),
  ];

  // Get all events
  List<Event> getEvents() {
    return _events;
  }

  // Get single event by ID
  Event? getEventById(String id) {
    try {
      return _events.firstWhere((event) => event.id == id);
    } catch (e) {
      return null;
    }
  }

  // Add new event
  void addEvent(Event event) {
    _events.add(event);
  }

  // Create new event (helper method)
  Event createEvent({
    required String title,
    required String description,
    required String category,
    required double latitude,
    required double longitude,
    required DateTime dateTime,
    required String locationName,
    String? imageUrl,
  }) {
    const uuid = Uuid();
    final event = Event(
      id: uuid.v4(),
      title: title,
      description: description,
      category: category,
      latitude: latitude,
      longitude: longitude,
      dateTime: dateTime,
      locationName: locationName,
      imageUrl: imageUrl ?? 'https://via.placeholder.com/300x200?text=${category}',
      submittedBy: 'user',
      createdAt: DateTime.now(),
    );

    addEvent(event);
    return event;
  }

  // Delete event
  void deleteEvent(String id) {
    _events.removeWhere((event) => event.id == id);
  }

  // Get events by category
  List<Event> getEventsByCategory(String category) {
    return _events.where((event) => event.category == category).toList();
  }
}