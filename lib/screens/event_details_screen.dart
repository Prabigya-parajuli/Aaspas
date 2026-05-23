import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/category_helper.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/user_service.dart';
import '../services/fcm_service.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final LocationService _locationService = LocationService();
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  final UserService _userService = UserService();

  bool _isAttending = false;
  bool _isSaved = false;
  bool _isLoading = true;
  bool _isAttendingLoading = false;
  bool _hasTrackedView = false;
  int _attendanceCount = 0;
  int _viewCount = 0;
  int _saveCount = 0;
  int _shareCount = 0;
  String? _submittedByUsername;

  @override
  void initState() {
    super.initState();
    _viewCount = widget.event.viewCount;
    _saveCount = widget.event.saveCount;
    _shareCount = widget.event.shareCount;
    _checkStatuses();
    _trackView();
    _loadSubmittedByUsername();
  }

  Future<void> _loadSubmittedByUsername() async {
    try {
      final userData = await _userService.getUserData(widget.event.submittedBy);
      if (mounted && userData != null) {
        setState(() {
          _submittedByUsername = userData.username;
        });
      }
    } catch (e) {
      debugPrint('Error loading username: $e');
    }
  }

  Future<void> _trackView() async {
    if (_hasTrackedView || widget.event.id.isEmpty) return;
    _hasTrackedView = true;
    final success = await _firebaseService.incrementViewCount(widget.event.id);
    if (success && mounted) {
      setState(() => _viewCount += 1);
    }
  }

  Future<void> _checkStatuses() async {
    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      final saved = await _userService.isEventSaved(userId, widget.event.id);
      final attending = await _userService.isAttending(userId, widget.event.id);
      final attendanceCounts =
      await _userService.getAttendanceCounts([widget.event.id]);
      setState(() {
        _isSaved = saved;
        _isAttending = attending;
        _attendanceCount = attendanceCounts[widget.event.id] ?? 0;
        _isLoading = false;
      });
    } else {
      final attendanceCounts =
      await _userService.getAttendanceCounts([widget.event.id]);
      setState(() {
        _attendanceCount = attendanceCounts[widget.event.id] ?? 0;
        _isLoading = false;
      });
    }
  }

  double? get _distance => _locationService.getDistanceToPoint(
    widget.event.latitude,
    widget.event.longitude,
  );

  Future<void> _toggleSave() async {
    final userId = _authService.getCurrentUserId();
    if (userId == null) return;
    setState(() => _isLoading = true);
    bool success;
    if (_isSaved) {
      success = await _userService.unsaveEvent(userId, widget.event.id);
    } else {
      success = await _userService.saveEvent(userId, widget.event.id);
    }
    if (success && mounted) {
      await _cacheService.clearUserCache(userId);
      if (_isSaved) {
        await _firebaseService.decrementSaveCount(widget.event.id);
      } else {
        await _firebaseService.incrementSaveCount(widget.event.id);
      }
      setState(() {
        _isSaved = !_isSaved;
        _saveCount += _isSaved ? 1 : -1;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isSaved ? '🔖 Event saved!' : 'Event unsaved')),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAttending() async {
    final userId = _authService.getCurrentUserId();
    if (userId == null) return;
    setState(() => _isAttendingLoading = true);
    bool success;
    if (_isAttending) {
      success = await _userService.unmarkAttending(userId, widget.event.id);
    } else {
      success = await _userService.markAttending(userId, widget.event.id);
    }
    if (success && mounted) {
      await _cacheService.clearUserCache(userId);
      if (_isAttending) {
        await _firebaseService.decrementAttendingCount(widget.event.id);
      } else {
        await _firebaseService.incrementAttendingCount(widget.event.id);
      }
      final attendanceCounts =
      await _userService.getAttendanceCounts([widget.event.id]);
      setState(() {
        _isAttending = !_isAttending;
        _attendanceCount = attendanceCounts[widget.event.id] ?? 0;
        _isAttendingLoading = false;
      });
      if (_isAttending) _scheduleAttendingReminder();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAttending
              ? ' You\'re going! We\'ll remind you the day before'
              : 'Removed from attending'),
        ),
      );
    } else if (mounted) {
      setState(() => _isAttendingLoading = false);
    }
  }

  Future<void> _scheduleAttendingReminder() async {
    final userId = _authService.getCurrentUserId();
    if (userId == null) return;
    final token = FCMService().fcmToken;
    if (token == null) return;
    final eventDate = widget.event.dateTime;
    final reminderDate = eventDate.subtract(const Duration(days: 1));
    final reminderAt = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9, 0,
    );
    if (reminderAt.isBefore(DateTime.now())) return;
    await FCMService().sendNotificationToUser(
      targetUserId: userId,
      targetToken: token,
      title: 'Event Tomorrow!',
      body:
      '${widget.event.title} is happening tomorrow at ${widget.event.locationName}',
      data: {'eventId': widget.event.id, 'type': 'reminder'},
    );
    debugPrint('✅ Reminder queued for: ${widget.event.title}');
  }

  void _shareEvent() {
    final eventDate = _formatDateTime(widget.event.dateTime);
    final location = widget.event.areaName != null
        ? '${widget.event.locationName}, ${widget.event.areaName}'
        : widget.event.locationName;
    final shareText = '''
 ${widget.event.title}

 $eventDate
 $location

${widget.event.description}

Shared from Aaspas - Hyperlocal Events''';
    _firebaseService.incrementShareCount(widget.event.id);
    setState(() => _shareCount += 1);
    Share.share(shareText);
  }

  void _showReportDialog() {
    final reasons = [
      'Spam or misleading',
      'Inappropriate content',
      'Fake event',
      'Wrong location',
      'Already happened',
      'Other',
    ];
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flag, color: Colors.red),
              SizedBox(width: 8),
              Text('Report Event'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why are you reporting this event?',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...reasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                value: reason,
                groupValue: selectedReason,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) =>
                    setDialogState(() => selectedReason = val),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                Navigator.pop(context);
                await _submitReport(selectedReason!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    final userId = _authService.getCurrentUserId();
    if (userId == null) return;
    try {
      await _firebaseService.reportEvent(
        eventId: widget.event.id,
        reportedBy: userId,
        reason: reason,
        eventTitle: widget.event.title,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Report submitted. Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to submit report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.getCurrentUserId();
    final isOwner = currentUserId == widget.event.submittedBy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareEvent,
            tooltip: 'Share Event',
          ),
          if (!isOwner)
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: Colors.red),
              onPressed: _showReportDialog,
              tooltip: 'Report Event',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEventImage(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleAndCategory(),
                  const SizedBox(height: 8),
                  _buildPostedBy(),
                  const SizedBox(height: 20),
                  _buildInfoSection(),
                  const SizedBox(height: 16),
                  _buildEngagementSection(),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                  const SizedBox(height: 24),
                  _buildLocationSection(),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventImage() {
    if (widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty) {
      return SizedBox(
        height: 220,
        width: double.infinity,
        child: Image.network(
          widget.event.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
        ),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: CategoryHelper.getLightColorForCategory(widget.event.category),
        border: Border(
          bottom: BorderSide(
            color: CategoryHelper.getColorForCategory(widget.event.category),
            width: 4,
          ),
        ),
      ),
      child: Center(
        child: Icon(
          CategoryHelper.getIconForCategory(widget.event.category),
          size: 100,
          color: CategoryHelper.getColorForCategory(widget.event.category),
        ),
      ),
    );
  }

  Widget _buildPostedBy() {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          _submittedByUsername != null
              ? 'Posted by @$_submittedByUsername'
              : 'Posted by user',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleAndCategory() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.event.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: CategoryHelper.getLightColorForCategory(widget.event.category),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CategoryHelper.getColorForCategory(widget.event.category),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CategoryHelper.getIconForCategory(widget.event.category),
                size: 16,
                color: CategoryHelper.getColorForCategory(widget.event.category),
              ),
              const SizedBox(width: 4),
              Text(
                widget.event.category,
                style: TextStyle(
                  color: CategoryHelper.getColorForCategory(widget.event.category),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      children: [
        _buildInfoRow(
          Icons.calendar_today,
          'Date & Time',
          _formatDateTime(widget.event.dateTime),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.storefront,
          'Venue',
          widget.event.locationName,
          subtitle: (widget.event.areaName != null && widget.event.areaName!.isNotEmpty)
              ? widget.event.areaName
              : null,
        ),
        if (_distance != null) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.directions_walk,
            'Distance',
            _distance! < 1
                ? '${(_distance! * 1000).toStringAsFixed(0)}m away'
                : '${_distance!.toStringAsFixed(1)}km away',
          ),
        ],
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.people_alt_outlined,
          'Attendance',
          _attendanceCount == 1
              ? '1 person attending'
              : '$_attendanceCount people attending',
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {String? subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 15)),
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildStatChip(Icons.visibility_outlined, '$_viewCount views'),
        _buildStatChip(Icons.bookmark_outline, '$_saveCount saves'),
        _buildStatChip(Icons.share_outlined, '$_shareCount shares'),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.blue[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(widget.event.description,
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Venue name
              Row(
                children: [
                  const Icon(Icons.storefront, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.event.locationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              // Area name (if exists)
              if (widget.event.areaName != null && widget.event.areaName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_city, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.event.areaName!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: SizedBox(
            height: 180,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(widget.event.latitude, widget.event.longitude),
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.aaspas',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.event.latitude, widget.event.longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isAttendingLoading ? null : _toggleAttending,
            icon: _isAttendingLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : Icon(_isAttending
                ? Icons.check_circle
                : Icons.event_available),
            label: Text(_isAttending ? "I'm Going! ✓" : "I'm Going"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(14),
              backgroundColor: _isAttending ? Colors.green : Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _toggleSave,
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
            label: Text(_isSaved ? 'Saved' : 'Save Event'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(14),
              foregroundColor: _isSaved ? Colors.orange : Colors.blue,
              side: BorderSide(color: _isSaved ? Colors.orange : Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}