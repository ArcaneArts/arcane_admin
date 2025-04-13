# arcane_admin

## Setup

Initialization is simple
```dart
import 'dart:io';

import 'package:arcane_admin/arcane_admin.dart';

void main() async {
  await ArcaneAdmin.initialize();
}
```

You can override the defaults like so
```dart
import 'dart:io';

import 'package:arcane_admin/arcane_admin.dart';

void main() async {
  // All fields are optional, you generally dont need to provide anything!
  // Every parameter is just the default value
  await ArcaneAdmin.initialize(
    projectId: "<project_id>",
    defaultStorageBucket: "<project_id>.appspot.com", // This is figured out by default
    credentials: null, // Defaults to environment variable reading
    database: "(default)",
    apiKey: null, // Generally not advisable, may prevent JWT validation
    cloudTasksRegion: "us-central1",
    firestoreBasePath: "",
    firestoreBaseUrl: "https://firestore.googleapis.com/",
  );
}
```

Normally environment variables are used to authenticate however you can pass your credentials in manually
```dart
import 'dart:io';

import 'package:arcane_admin/arcane_admin.dart';
import 'package:googleapis_auth/auth_browser.dart';

void main() async {
  await ArcaneAdmin.initialize(
      // Pass in service account credentials read from file
      credentials: ServiceAccountCredentials.fromJson(File("creds.json")
          .readAsStringSync())
  );
}
```

# Firestore

This uses [fire_api](https://pub.dev/packages/fire_api) under the hood. View that documentation on how to use firestore for more information.

```dart
DocumentSnapshot snap = await ArcaneAdmin
    .collection("user")
    .doc("dan")
    .get();

print(snap.exists ? snap.data : "No data");

// You can also access the firestore database object from fire_api with
ArcaneAdmin.firestore
    .collection(...)
    .doc(...)
    .get();
```

# Cloud Storage

This also uses [fire_api](https://pub.dev/packages/fire_api#firebase-storage-api) view the storage section for more details.

```dart
FireStorageRef r = Arcane.ref("some/file");

Future<Uint8List> read = r.read();
Future<void> written = r.write(Uint8List);

// You can also access the fire_api storage api directly
ArcaneAdmin.storage
    .bucket("custom_bucket")
    .ref(...)
    .read();
```

# Messaging

You can send messages using the messaging api

```dart
ArcaneAdmin.messaging
    .sendMulticast(
      FMulticastMessage(
        tokens: ["fcm1", "fcm2", ...],
        data: {"data": jsonEncode(data.toMap())},
        notification: FNotification(title: title, body: body),
        android: FAndroidConfig(priority: AndroidConfigPriority.normal),
        apns: FApnsConfig(
          headers: {"apns-priority": "5"},
          payload: FApnsPayload(
            aps: FAps(
              sound: "default", 
              interruptionLevel: "time-sensitive"
            ),
          ),
        ),
      )
    );
```

# Cloud Tasks

You can schedule a task in cloud tasks to any endpoint

```dart
ArcaneAdmin.tasks.scheduleTask(
  queue: "barbequeue", 
  url: "https://api.server.com/some/endpoint", 
  body: {
    "do": "something",
    "data": true
  }
);
```

Then, when it hits your server, you can validate the JWT provided to prove it came from GCM

```dart
// Using shelf Request from shelf package
Future<Response> onSomeTask(Request request) async {
  if(!await ArcaneAdmin.validation.validateGCPRequestJWT(request)) {
    return Response.forbidden("Unauthenticated");
  }
  
  return Response.ok("Job's done!");
}
```