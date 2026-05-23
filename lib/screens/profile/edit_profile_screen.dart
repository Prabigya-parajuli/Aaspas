import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/image_picker_service.dart';
import '../../utils/input_validator.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final ImagePickerService _imagePickerService = ImagePickerService();

  final _usernameController = TextEditingController();
  String? _currentPhotoURL;
  XFile? _selectedImageFile;
  String? _uploadedImageUrl;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = _authService.getCurrentUserId();
    if (userId == null) return;

    final user = await _authService.getUserData(userId);
    if (user != null && mounted) {
      setState(() {
        _usernameController.text = user.username;
        _currentPhotoURL = user.photoURL;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final imageFile = source == ImageSource.camera
        ? await _imagePickerService.pickImageFromCamera()
        : await _imagePickerService.pickImageFromGallery();

    if (imageFile != null && mounted) {
      setState(() {
        _selectedImageFile = imageFile;
        _uploadedImageUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image selected. Tap Save to upload.')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final newUsername = _usernameController.text.trim();

    // Validate username
    if (newUsername.isEmpty) {
      setState(() {
        _errorMessage = 'Username cannot be empty';
      });
      return;
    }

    if (newUsername.length < 3) {
      setState(() {
        _errorMessage = 'Username must be at least 3 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userId = _authService.getCurrentUserId();
    if (userId == null) return;

    String? photoUrl = _currentPhotoURL;

    // Upload new image if selected
    if (_selectedImageFile != null) {
      setState(() => _isUploading = true);
      try {
        photoUrl = await _imagePickerService.uploadProfileImage(_selectedImageFile!);
        if (photoUrl == null) {
          setState(() => _errorMessage = 'Failed to upload image');
          return;
        }
      } catch (e) {
        setState(() => _errorMessage = 'Image upload failed: $e');
        return;
      } finally {
        setState(() => _isUploading = false);
      }
    }

    // Update Firestore
    final success = await _userService.updateUserProfile(userId, {
      'username': newUsername,
      if (photoUrl != null) 'photoURL': photoUrl,
    });

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = 'Failed to update profile';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _selectedImageFile != null
                        ? FileImage(File(_selectedImageFile!.path))
                        : (_currentPhotoURL != null && _currentPhotoURL!.isNotEmpty
                        ? NetworkImage(_currentPhotoURL!)
                        : null),
                    child: (_selectedImageFile == null &&
                        (_currentPhotoURL == null || _currentPhotoURL!.isEmpty))
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        onPressed: _isUploading ? null : _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isUploading) ...[
              const SizedBox(height: 8),
              const Text('Uploading image...', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 32),

            // Username field
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 24),

            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your profile picture and username will appear on events you create.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}