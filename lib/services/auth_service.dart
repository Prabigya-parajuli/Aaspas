import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  firebase_auth.User? get currentFirebaseUser => _auth.currentUser;
  firebase_auth.User? get currentUser => _auth.currentUser;

  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> isEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('Verification email sent to ${user.email}');
      }
    } catch (e) {
      print('Error sending verification email: $e');
      rethrow;
    }
  }

  Future<String?> signup({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return 'Failed to create user';
      }

      await firebaseUser.sendEmailVerification();
      print('Verification email sent to $email');

      final user = User(
        id: firebaseUser.uid,
        username: username,
        favoriteCategories: [],
        savedEventIds: [],
        attendingEventIds: [],
        eventsAttended: 0,
        eventsSaved: 0,
        eventsCreated: 0,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set(
        user.toMap(),
        SetOptions(merge: true),
      );

      await _auth.signOut();

      print('User signed up successfully: $email (UID: ${firebaseUser.uid})');
      print('User data saved to Firestore');
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Signup Firebase error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Please login instead.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled.';
        case 'weak-password':
          return 'Password is too weak. Please use a stronger password.';
        default:
          return e.message ?? 'An error occurred during signup';
      }
    } on FirebaseException catch (e) {
      print('Firestore error: ${e.code} - ${e.message}');
      return 'Failed to save user data. Please try again.';
    } catch (e) {
      print('Unexpected error during signup: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await firebaseUser.reload();
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'lastLogin': DateTime.now().toIso8601String(),
        });

        print('User logged in successfully: $email (UID: ${firebaseUser.uid})');
      }

      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Login Firebase error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        default:
          return e.message ?? 'An error occurred during login';
      }
    } catch (e) {
      print('Unexpected error during login: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      print('User logged out successfully');
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  Future<User?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        print('User data retrieved for UID: $uid');
        return User.fromMap(data);
      }
      print('No user data found for UID: $uid');
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<bool> emailExists(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  Future<bool> usernameExists(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking username: $e');
      return false;
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('Password reset email sent to $email');
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Password reset error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'invalid-email':
          return 'Invalid email address.';
        default:
          return e.message ?? 'An error occurred';
      }
    } catch (e) {
      print('Unexpected error during password reset: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<firebase_auth.User?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Check if user document exists in Firestore
        final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();

        if (!userDoc.exists) {
          // Create user document for Google sign-in
          final user = User(
            id: firebaseUser.uid,
            username: googleUser.displayName ?? firebaseUser.email?.split('@').first ?? 'user',
            favoriteCategories: [],
            savedEventIds: [],
            attendingEventIds: [],
            eventsAttended: 0,
            eventsSaved: 0,
            eventsCreated: 0,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
          );

          await _firestore.collection('users').doc(firebaseUser.uid).set(user.toMap());
          print('Created user document for Google user: ${user.username}');
        } else {
          // Update last login
          await _firestore.collection('users').doc(firebaseUser.uid).update({
            'lastLogin': DateTime.now().toIso8601String(),
          });
        }
      }

      return firebaseUser;
    } catch (e) {
      print('Google sign in failed: $e');
      return null;
    }
  }

  Future<bool> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
      print('User profile updated');
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).delete();
        await user.delete();
        print('Account deleted');
      }
    } catch (e) {
      print('Delete account error: $e');
      rethrow;
    }
  }

  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  String? getCurrentUserEmail() {
    return _auth.currentUser?.email;
  }
}