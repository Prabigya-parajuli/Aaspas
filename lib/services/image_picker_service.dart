import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImagePickerService {
  static const int maxImageBytes = 3 * 1024 * 1024;
  static const int uploadImageQuality = 75;
  static const double maxImageWidth = 1600;
  static const double maxImageHeight = 1600;

  static final ImagePickerService _instance = ImagePickerService._internal();

  factory ImagePickerService() {
    return _instance;
  }

  ImagePickerService._internal();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: uploadImageQuality,
        maxWidth: maxImageWidth,
        maxHeight: maxImageHeight,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: uploadImageQuality,
        maxWidth: maxImageWidth,
        maxHeight: maxImageHeight,
      );
      return image;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  // Upload image to Firebase Storage
  Future<String?> uploadEventImage(XFile imageFile) async {
    try {
      final fileSize = await getImageFileSize(imageFile);
      if (fileSize != null && fileSize > maxImageBytes) {
        throw Exception(
            'Image is too large. Please choose an image under 3 MB.');
      }

      const uuid = Uuid();
      final fileName = 'events/${uuid.v4()}.jpg';

      final ref = _storage.ref().child(fileName);
      debugPrint('Uploading image to Storage path: $fileName');
      final uploadTask = ref.putFile(
        File(imageFile.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final taskSnapshot = await uploadTask;
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      debugPrint('Storage upload success: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint(
        'Firebase Storage upload error [${e.code}]: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Pick and upload in one go
  Future<String?> pickAndUploadImage(ImageSource source) async {
    try {
      final image = source == ImageSource.camera
          ? await pickImageFromCamera()
          : await pickImageFromGallery();

      if (image == null) return null;

      final fileSize = await getImageFileSize(image);
      if (fileSize != null && fileSize > maxImageBytes) {
        throw Exception(
            'Image is too large. Please choose an image under 3 MB.');
      }

      final uploadedUrl = await uploadEventImage(image);
      return uploadedUrl;
    } catch (e) {
      debugPrint('Error in pickAndUploadImage: $e');
      return null;
    }
  }

  // Get file size
  Future<int?> getImageFileSize(XFile file) async {
    try {
      final imageFile = File(file.path);
      final bytes = await imageFile.readAsBytes();
      return bytes.length;
    } catch (e) {
      debugPrint('Error getting file size: $e');
      return null;
    }
  }

  Future<String?> uploadProfileImage(XFile imageFile) async {
    try {
      print('Starting profile image upload...');
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('No user ID found');
        return null;
      }
      print('User ID: $userId');

      final fileName = 'profile_$userId.jpg';
      final ref = FirebaseStorage.instance.ref().child('profile_pics/$fileName');
      print('Storage ref created: ${ref.fullPath}');

      // Read image as bytes
      final bytes = await File(imageFile.path).readAsBytes();

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'compressed': 'true'},
      );

      await ref.putData(bytes, metadata).timeout(const Duration(seconds: 15));
      print('File uploaded');

      final downloadUrl = await ref.getDownloadURL();
      print('Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('Upload failed: $e');
      return null;
    }
  }
}