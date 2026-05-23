import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/event_model.dart';
import '../../services/firebase_service.dart';
import '../../services/location_service.dart';
import '../../services/category_helper.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/user_service.dart';
import '../../services/fcm_service.dart';
import '../../services/image_picker_service.dart';
import '../../utils/input_validator.dart';
import '../../widgets/email_verification_banner.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({Key? key}) : super(key: key);

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  final UserService _userService = UserService();
  final ImagePickerService _imagePickerService = ImagePickerService();
  final MapController _mapController = MapController();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationSearchController = TextEditingController();

  String? _selectedCategory;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _showValidationErrors = false;
  XFile? _selectedImageFile;
  String? _uploadedImageUrl;

  // Location data
  LatLng? _selectedLocation;
  String? _selectedLocationName;  // User typed specific name e.g. "Funky Buddha Cafe"
  String? _selectedAreaName;      // Reverse geocoded e.g. "Thamel, Kathmandu"
  bool _isSearchingLocation = false;
  bool _isReverseGeocoding = false;

  final _specificLocationController = TextEditingController(); // NEW

  final List<String> _categories = ['Tech', 'Health', 'Culture', 'Sports', 'Volunteer', 'Other'];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) {
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationSearchController.dispose();
    _specificLocationController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation() async {
    final query = _locationSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location to search')),
      );
      return;
    }

    setState(() {
      _isSearchingLocation = true;
    });

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        final location = locations.first;
        setState(() {
          _selectedLocation = LatLng(location.latitude, location.longitude);
          _selectedLocationName = query;
        });
        _mapController.move(_selectedLocation!, 16.0);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location found! Adjust pin if needed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location not found: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLocation = false;
        });
      }
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    setState(() => _isReverseGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((p) => p != null && p.isNotEmpty).toList();
        final areaName = parts.join(', ');
        setState(() {
          _selectedAreaName = areaName;
          _isReverseGeocoding = false;
        });
        print('📍 Area: $areaName');
      }
    } catch (e) {
      setState(() => _isReverseGeocoding = false);
      print('❌ Reverse geocoding failed: $e');
    }
  }

  void _openMapPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Select Location'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
              body: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationSearchController,
                            decoration: InputDecoration(
                              hintText: 'Search location...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onSubmitted: (_) => _searchLocation(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSearchingLocation ? null : _searchLocation,
                          child: _isSearchingLocation
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Text('Search'),
                        ),
                      ],
                    ),
                  ),
                  // Map
                  Expanded(
                    child: _selectedLocation != null
                        ? FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation!,
                        initialZoom: 15.0,
                        onTap: (tapPosition, latLng) {
                          setModalState(() {
                            _selectedLocation = latLng;
                          });
                          setState(() {
                            _selectedLocation = latLng;
                          });
                          // Reverse geocode to get area name
                          _reverseGeocode(latLng);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.aaspas',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation!,
                              width: 80,
                              height: 80,
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 50,
                                    color: Colors.red,
                                  ),
                                  Text(
                                    'Event here',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                        : const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap anywhere on the map to place your event marker',
                            style: TextStyle(color: Colors.blue[900], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickEventImage(ImageSource source) async {
    try {
      final imageFile = source == ImageSource.camera
          ? await _imagePickerService.pickImageFromCamera()
          : await _imagePickerService.pickImageFromGallery();

      if (!mounted) return;

      if (imageFile != null) {
        final fileSize = await _imagePickerService.getImageFileSize(imageFile);
        if (!mounted) return;

        if (fileSize != null &&
            fileSize > ImagePickerService.maxImageBytes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image is too large. Please choose one under 3 MB.'),
            ),
          );
          return;
        }

        setState(() {
          _selectedImageFile = imageFile;
          _uploadedImageUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image selected and ready to upload')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickEventImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickEventImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to check rate limit
  Future<bool> _checkRateLimit() async {
    final userId = _authService.getCurrentUserId();
    if (userId == null || userId == 'anonymous') return true; // Anonymous users can't create events anyway

    try {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));

      final querySnapshot = await _firebaseService
          .getEventsByUser(userId)
          .then((events) => events.where((e) => e.createdAt.isAfter(twentyFourHoursAgo)).toList());

      if (querySnapshot.length >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have reached the limit of 5 events per day. Please try again tomorrow.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      print('Rate limit check failed: $e');
      return true; // Allow on error to not block users
    }
  }

  Future<void> _submitEvent() async {
    final isVerified = await _authService.isEmailVerified();
    if (!isVerified) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify your email before creating events. Check your inbox!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _showValidationErrors = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the highlighted fields and try again.'),
        ),
      );
      debugPrint('Create event blocked by form validation');
      return;
    }

    // RATE LIMIT CHECK HERE
    final withinLimit = await _checkRateLimit();
    if (!withinLimit) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select location on map')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? imageUrl = _uploadedImageUrl;
      if (_selectedImageFile != null && imageUrl == null) {
        try {
          setState(() => _isUploadingImage = true);
          imageUrl = await _imagePickerService
              .uploadEventImage(_selectedImageFile!)
              .timeout(const Duration(seconds: 20));

          if (!mounted) return;

          setState(() {
            _uploadedImageUrl = imageUrl;
            _isUploadingImage = false;
          });

          if (imageUrl == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image upload failed, so the event will be created without an image.'),
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          setState(() => _isUploadingImage = false);
          imageUrl = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Image upload timed out or failed. Creating the event without an image.',
              ),
            ),
          );
        }
      }

      final eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final userId = _authService.getCurrentUserId() ?? 'anonymous';

      final event = Event(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        dateTime: eventDateTime,
        locationName: _specificLocationController.text.trim().isNotEmpty
            ? _specificLocationController.text.trim()
            : (_locationSearchController.text.trim().isNotEmpty
            ? _locationSearchController.text.trim()
            : (_selectedAreaName?.trim().isNotEmpty ?? false)
            ? _selectedAreaName!
            : 'Selected Location'),
        areaName: _selectedAreaName,
        imageUrl: imageUrl,
        submittedBy: userId,
        createdAt: DateTime.now(),
      );

      print('Submitting event: ${event.title}');
      final eventId = await _firebaseService.addEvent(event);
      print('Add event result: $eventId');

      if (eventId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
        Navigator.pop(context);

        _runPostCreateTasks(
          userId: userId,
          eventId: eventId,
          eventTitle: _titleController.text.trim(),
          eventCategory: _selectedCategory!,
          eventLat: _selectedLocation!.latitude,
          eventLng: _selectedLocation!.longitude,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error creating event')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _runPostCreateTasks({
    required String userId,
    required String eventId,
    required String eventTitle,
    required String eventCategory,
    required double eventLat,
    required double eventLng,
  }) async {
    try {
      if (userId != 'anonymous') {
        await _userService.incrementEventsCreated(userId);
        await _cacheService.clearUserCache(userId);
      }
      await _cacheService.clearEventsCache();

      await FCMService().notifyNearbyUsersOfNewEvent(
        eventTitle: eventTitle,
        eventCategory: eventCategory,
        eventId: eventId,
        eventLat: eventLat,
        eventLng: eventLng,
      );
    } catch (e) {
      print('Post-create tasks failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: _showValidationErrors
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EmailVerificationBanner(),
              const SizedBox(height: 16),
              Text(
                'Create a New Event',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Share an event happening near you',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              _buildEventTitleField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              _buildImageSection(),
              const SizedBox(height: 16),
              _buildLocationSection(),
              const SizedBox(height: 16),
              _buildDateTimeSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'Event Title *',
        hintText: 'e.g., Blood Donation Drive',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.title),
      ),
      validator: InputValidator.validateTitle,
      maxLength: 100,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Description *',
        hintText: 'Describe your event in detail',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.description),
      ),
      validator: InputValidator.validateDescription,
      maxLines: 4,
      maxLength: 500,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.category),
      ),
      hint: const Text('Select a category'),
      items: _categories
          .map((category) => DropdownMenuItem(
        value: category,
        child: Row(
          children: [
            Icon(
              CategoryHelper.getIconForCategory(category),
              size: 18,
              color: CategoryHelper.getColorForCategory(category),
            ),
            const SizedBox(width: 12),
            Text(category),
          ],
        ),
      ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      validator: (value) => value == null ? 'Please select a category' : null,
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location *',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        // Map preview or button to open map
        GestureDetector(
          onTap: _openMapPicker,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _selectedLocation != null
                  ? Stack(
                children: [
                  AbsorbPointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _selectedLocation!,
                        initialZoom: 15.0,
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
                              point: _selectedLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                size: 40,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_location, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Tap to change',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_location, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to select location',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_selectedLocation != null) ...[
          const SizedBox(height: 12),
          // Area name from reverse geocoding
          if (_isReverseGeocoding)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Getting area name...', style: TextStyle(fontSize: 12)),
                ],
              ),
            )
          else if (_selectedAreaName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_city, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'Area: $_selectedAreaName',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ),
          // Specific location name field
          TextFormField(
            controller: _specificLocationController,
            decoration: InputDecoration(
              labelText: 'Venue/Place Name',
              hintText: 'e.g., Funky Buddha Cafe, Bhatbhateni Supermarket',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.storefront),
              helperText: 'Optional: enter a specific venue or landmark name',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              }
              return InputValidator.validateLocationName(value);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Image',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploadingImage ? null : _showImagePickerOptions,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isUploadingImage
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Uploading image...'),
                  ],
                ),
              )
                  : _selectedImageFile != null
                  ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(_selectedImageFile!.path),
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedImageFile = null;
                            _uploadedImageUrl = null;
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
                  : _uploadedImageUrl != null
                  ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _uploadedImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildImagePlaceholder();
                    },
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedImageFile = null;
                            _uploadedImageUrl = null;
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
                  : _buildImagePlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add a real event photo to make your listing stand out. Max 3 MB.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_a_photo, size: 42, color: Colors.grey),
        const SizedBox(height: 8),
        Text(
          'Tap to add event image',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date & Time *',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Select date'
                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _selectTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Time',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.access_time),
                  ),
                  child: Text(
                    _selectedTime == null
                        ? 'Select time'
                        : _selectedTime!.format(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isSubmitting || _isUploadingImage) ? null : _submitEvent,
        icon: (_isSubmitting || _isUploadingImage)
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.check),
        label: Text(
          _isUploadingImage
              ? 'Uploading Image...'
              : (_isSubmitting ? 'Creating Event...' : 'Create Event'),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}