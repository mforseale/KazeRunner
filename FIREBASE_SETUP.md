# Firebase setup for Kaze Runner

The app already contains Firebase Auth and Firestore integration. Without a
Firebase project config it safely falls back to local storage.

Current project id: `kazerunner`.

Firestore rules were deployed to `kazerunner` on 2026-05-24.

## 1. Add Firebase config

Install FlutterFire CLI and connect the app to your Firebase project:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Select Android and iOS at minimum. This generates `lib/firebase_options.dart`
and platform config files. If you use manual setup instead, add:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

## 2. Enable Auth providers

In Firebase Console, enable:

- Email/password
- Google
- Apple

Google native sign-in is implemented through `google_sign_in` and then
Firebase `signInWithCredential`.

Android debug SHA fingerprints added to Firebase app
`1:508621449910:android:9ed15e4c3f81854a145417`:

```text
SHA-1:   F8:17:CF:1C:E6:3E:16:EE:09:19:99:B0:D1:88:DB:A5:A0:58:0A:3F
SHA-256: B3:0E:FD:72:B4:14:BE:60:CE:24:58:DA:1C:43:09:B4:F9:29:2B:BB:5D:9A:F0:4A:3D:2C:9D:51:BA:59:DE:BF
```

For iOS Google sign-in, `Info.plist` contains the `REVERSED_CLIENT_ID` URL
scheme from `GoogleService-Info.plist`. For Apple sign-in, `Runner.entitlements`
contains `com.apple.developer.applesignin`.

## 3. Firestore rules

The repository contains `firestore.rules`. Deploy it with:

```powershell
firebase deploy --only firestore:rules
```

The rules let users access only their own account document and app state:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    match /users/{userId} {
      allow read, create, update, delete: if isOwner(userId);

      match /appState/{docId} {
        allow read, create, update, delete: if isOwner(userId);
      }
    }
  }
}
```

## 4. 30-day retention

The app writes an `expiresAt` timestamp on every save:

```text
users/{uid}/appState/current.expiresAt
```

Enable Firestore TTL for the `expiresAt` field in the `appState` collection
group. Each profile/progress document will be eligible for deletion 30 days
after the last app save.
