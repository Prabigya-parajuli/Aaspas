Aaspas — Hyperlocal Event Discovery App
Aaspas is a Flutter and Firebase mobile application for discovering nearby community events in Nepal including blood drives, workshops, cultural programs, and volunteer opportunities.
---
Overview
The app is built around one core idea:
> **Events should be found because they are nearby, not because they are popular.**
That principle drives location-first discovery, equity-based visibility, and offline caching for Nepal's network conditions.
---
Main Features
Email/Password authentication with email verification
Google Sign In
Location-based event discovery within 1–5 km radius
Personalized event recommendations using weighted scoring
Create, edit, and delete events with image upload
Save events to personal collection
Mark attendance with push notification reminders
Offline caching for unstable internet
Search by title, description, category, or location
Category filtering (Tech, Health, Culture, Sports, Volunteer, Other)
Interactive map with event markers using OpenStreetMap
User profile with profile picture upload
Admin dashboard for moderation and analytics
Report inappropriate events
Rate limiting (5 events per user per 24 hours)
---
Tech Stack
Layer	Technology
Framework	Flutter / Dart
Authentication	Firebase Authentication
Database	Cloud Firestore
Storage	Firebase Storage
Notifications	Firebase Cloud Messaging
Maps	OpenStreetMap (flutter_map)
Location	Geolocator
Local Storage	Shared Preferences
Testing	Flutter Test
---
Project Structure
```
lib/
├── models/
├── screens/
│   ├── admin/
│   ├── auth/
│   ├── forms/
│   └── profile/
├── services/
├── utils/
└── widgets/
test/
android/
```
---
Getting Started
Prerequisites
Flutter SDK 3.0 or higher
Android SDK
Android device or emulator (API 21+)
Run a quick check:
```bash
flutter doctor
```
---
1. Clone the Repository
```bash
git clone <your-repo-url>
cd aaspas
```
2. Install Flutter Dependencies
```bash
flutter pub get
```
3. Set Up Firebase
Create a Firebase project and enable:
Authentication
Cloud Firestore
Firebase Storage
Firebase Cloud Messaging
Enable these auth providers:
Email/Password
Google Sign In
Register the Android app with the package name:
```
com.example.aaspas
```
Place the downloaded `google-services.json` in:
```
android/app/
```
4. Set Up Firestore Rules
Go to Firestore Console → Rules and add:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /events/{eventId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid == resource.data.submittedBy;
      allow delete: if request.auth != null && request.auth.uid == resource.data.submittedBy;
    }
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /reports/{reportId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null && request.auth.token.email == "adminaaspaas@gmail.com";
    }
  }
}
```
5. Set Up Storage Rules
Go to Storage Console → Rules and add:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```
6. Run the App
```bash
flutter run
```
To target Android specifically:
```bash
flutter run -d android
```
---
Testing
```bash
flutter test
```

Build Commands
```bash
# Debug APK
flutter build apk

# Release APK
flutter build apk --release
```
---
Admin Access
To test admin features:
Create a user account in the app.
Open the Firestore Console.
In the `users` collection, set the user document field: `email = adminaaspaas@gmail.com`
The admin panel will then be available in the Profile screen.
---
Known Limitations
Android only (iOS not supported)
Internet required for first-time load
No payment or ticketing system
English language only
Single image per event
---
Future Enhancements
iOS version
Calendar integration
Nepali language support
QR code check-in
---
