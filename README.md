# arcane_admin

`arcane_admin` provides Firebase Admin support for Arcane servers. It wraps the Google Cloud and Firebase admin APIs behind a single initializer and exposes ready-to-use helpers for:

- Firestore
- Cloud Storage
- Firebase Cloud Messaging
- Cloud Tasks
- JWT validation for authenticated Cloud Tasks requests
- Eventarc document and storage event handling

The package also re-exports [`fire_api`](https://pub.dev/packages/fire_api), so you can use the Firestore and Storage types from the same import.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  arcane_admin: ^1.5.8
```

Then fetch dependencies:

```bash
dart pub get
```

## Quick Start

Call `ArcaneAdmin.initialize()` once during server startup before using any of the admin services.

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> main() async {
  await ArcaneAdmin.initialize();

  print("Initialized Firebase admin for ${ArcaneAdmin.projectId}");
}
```

By default, initialization uses Application Default Credentials and attempts to discover the active Google Cloud project automatically.

## Authentication

`ArcaneAdmin.initialize()` supports three authentication modes:

1. `apiKey`
2. `credentials`
3. Application Default Credentials from the environment

If you do not provide `apiKey` or `credentials`, the package falls back to Google Application Default Credentials.

### Application Default Credentials

This is the simplest setup for most servers and Cloud Run / GCE / GKE environments.

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
```

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> main() async {
  await ArcaneAdmin.initialize();
}
```

### Service Account Credentials

You can also pass a service account explicitly.

```dart
import 'dart:io';

import 'package:arcane_admin/arcane_admin.dart';
import 'package:googleapis_auth/auth_io.dart';

Future<void> main() async {
  await ArcaneAdmin.initialize(
    credentials: ServiceAccountCredentials.fromJson(
      File("creds.json").readAsStringSync(),
    ),
  );
}
```

### Full Initialization Options

All initialization fields are optional except where your deployment requires a specific override.

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> main() async {
  await ArcaneAdmin.initialize(
    projectId: "my-project-id",
    defaultStorageBucket: "my-project-id.appspot.com",
    credentials: null,
    database: "(default)",
    apiKey: null,
    cloudTasksRegion: "us-central1",
    firestoreBasePath: "",
    firestoreBaseUrl: "https://firestore.googleapis.com/",
  );
}
```

### Initialization Notes

- `projectId` is resolved automatically when possible.
- `defaultStorageBucket` defaults to `<projectId>.firebasestorage.app`.
- If your Firebase project still uses the older `appspot.com` bucket naming, set `defaultStorageBucket` explicitly.
- `apiKey` works for some operations, but it is generally not a good default for admin/server environments.
- JWT validation for Cloud Tasks is strongest when a service account email is available.

## Available Admin Clients

After initialization, the following static clients are available:

- `ArcaneAdmin.firestore`
- `ArcaneAdmin.storage`
- `ArcaneAdmin.messaging`
- `ArcaneAdmin.tasks`
- `ArcaneAdmin.validation`
- `ArcaneAdmin.events`
- `ArcaneAdmin.client`

Useful helpers are also exposed:

- `ArcaneAdmin.projectId`
- `ArcaneAdmin.defaultStorageBucket`
- `ArcaneAdmin.serviceAccountEmail`
- `ArcaneAdmin.bucket([bucketName])`
- `ArcaneAdmin.ref(path, bucket: "...")`

## Firestore

Firestore support is powered by [`fire_api`](https://pub.dev/packages/fire_api).

Use the database client directly:

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> readUser() async {
  DocumentSnapshot snapshot = await ArcaneAdmin.firestore
      .collection("users")
      .doc("dan")
      .get();

  if (!snapshot.exists) {
    print("User not found");
    return;
  }

  print(snapshot.data);
}
```

Writing a document:

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> writeUser() async {
  await ArcaneAdmin.firestore.collection("users").doc("dan").set({
    "name": "Dan",
    "role": "admin",
    "enabled": true,
  });
}
```

Because `fire_api` is re-exported, common Firestore and Storage types can be imported from `package:arcane_admin/arcane_admin.dart`.

## Cloud Storage

Cloud Storage is also backed by [`fire_api`](https://pub.dev/packages/fire_api#firebase-storage-api).

Read and write a file in the default bucket:

```dart
import 'dart:typed_data';

import 'package:arcane_admin/arcane_admin.dart';

Future<void> storageExample() async {
  FireStorageRef file = ArcaneAdmin.ref("backups/config.json");

  await file.write(Uint8List.fromList([1, 2, 3, 4]));
  Uint8List bytes = await file.read();

  print("Read ${bytes.length} bytes");
}
```

Use a custom bucket:

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> customBucketExample() async {
  FireStorageRef file = ArcaneAdmin.ref(
    "exports/report.json",
    bucket: "my-custom-bucket",
  );

  await file.delete();
}
```

You can also access the storage API manually:

```dart
ArcaneAdmin.storage
    .bucket("my-custom-bucket")
    .ref("images/avatar.png")
    .read();
```

## Messaging

Use `ArcaneAdmin.messaging` to send Firebase Cloud Messaging notifications.

### Send To A Single Device Token

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> sendTokenMessage(String token) async {
  await ArcaneAdmin.messaging.send(
    FTokenMessage(
      token: token,
      data: {"screen": "orders", "orderId": "1234"},
      notification: FNotification(
        title: "Order updated",
        body: "Your order is ready for pickup.",
      ),
      android: FAndroidConfig(priority: AndroidConfigPriority.high),
      apns: FApnsConfig(
        headers: {"apns-priority": "10"},
        payload: FApnsPayload(
          aps: FAps(sound: "default", interruptionLevel: "time-sensitive"),
        ),
      ),
    ),
  );
}
```

### Send To A Topic

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> sendTopicMessage() async {
  await ArcaneAdmin.messaging.send(
    FTopicMessage(
      topic: "system-alerts",
      notification: FNotification(
        title: "Maintenance window",
        body: "Scheduled maintenance starts in 10 minutes.",
      ),
      data: {"type": "maintenance"},
    ),
  );
}
```

### Multicast Example

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> sendMulticast(List<String> tokens) async {
  await ArcaneAdmin.messaging.sendMulticast(
    FMulticastMessage(
      tokens: tokens,
      data: {"event": "refresh"},
      notification: FNotification(
        title: "Sync requested",
        body: "Please refresh your local cache.",
      ),
    ),
  );
}
```

### Messaging Notes

- `sendAll` and `sendMulticast` support up to 500 messages/tokens per call.
- Message payload helpers are available for Android, APNs, and WebPush configuration.
- All sends target `projects/<projectId>` automatically after initialization.

## Cloud Tasks

You can enqueue authenticated HTTP Cloud Tasks with `ArcaneAdmin.tasks.scheduleTask`.

```dart
import 'package:arcane_admin/arcane_admin.dart';

Future<void> scheduleTask() async {
  String? taskName = await ArcaneAdmin.tasks.scheduleTask(
    queue: "barbequeue",
    url: "https://api.example.com/internal/process-order",
    body: {
      "orderId": "1234",
      "force": true,
    },
    scheduleTime: DateTime.now().add(const Duration(minutes: 5)),
  );

  print("Created task: $taskName");
}
```

### Cloud Tasks Notes

- Requests are sent as JSON `POST` bodies.
- The package attaches an OIDC token using the active service account when one is available.
- `scheduleTime` defaults to "now" if omitted.
- `cloudTasksRegion` defaults to `us-central1`, but you can override it during initialization.

## Validating Cloud Tasks Requests

When Cloud Tasks calls your server, validate the bearer token before processing the request.

```dart
import 'package:arcane_admin/arcane_admin.dart';
import 'package:shelf/shelf.dart';

Future<Response> onSomeTask(Request request) async {
  bool valid = await ArcaneAdmin.validation.validateGCPRequestJWT(
    request,
    verifyAudience: "https://api.example.com/internal/process-order",
  );

  if (!valid) {
    return Response.forbidden("Unauthenticated");
  }

  return Response.ok("Job complete");
}
```

If you pass `verifyAudience`, it must match the target URL used when the task was created.

## Eventarc Helpers

The package includes helpers for handling Firestore document events and Cloud Storage events from Eventarc in `shelf` handlers.

## Firestore Document Event Example

```dart
import 'package:arcane_admin/arcane_admin.dart';
import 'package:shelf/shelf.dart';

Future<Response> onDocumentWebhook(Request request) {
  return request.documentEvent((ArcaneDocumentEvent event) async {
    print("Document path: ${event.documentPath}");
    print("IDs: ${event.ids}");
    print("Before: ${event.before}");
    print("After: ${event.after}");

    String? userId = event.ids["users"];
    return Response.ok("Processed change for $userId");
  });
}
```

`ArcaneDocumentEvent` includes:

- `documentPath`
- `ids`
- `before`
- `after`
- `request`
- `rawEventData`

## Storage Event Example

```dart
import 'package:arcane_admin/arcane_admin.dart';
import 'package:shelf/shelf.dart';

Future<Response> onStorageWebhook(Request request) {
  return request.storageEvent((ArcaneStorageEvent event) async {
    print("Bucket: ${event.bucket}");
    print("Path: ${event.path}");
    print("Content type: ${event.contentType}");

    return Response.ok("Storage event received");
  });
}
```

## Typical Server Startup Example

```dart
import 'package:arcane_admin/arcane_admin.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  await ArcaneAdmin.initialize(
    projectId: "my-project-id",
    cloudTasksRegion: "us-central1",
  );

  Handler app = (Request request) {
    if (request.url.path == "health") {
      return Future.value(Response.ok("ok"));
    }

    return Future.value(Response.notFound("Not found"));
  };

  await io.serve(app, "0.0.0.0", 8080);
}
```

## Best Practices

- Initialize once during process startup.
- Prefer service account credentials or Application Default Credentials for server environments.
- Set `defaultStorageBucket` explicitly if your Firebase project uses a non-default bucket name.
- Validate Cloud Tasks JWTs on every internal task endpoint.
- Use `ArcaneAdmin.firestore` and `ArcaneAdmin.storage` when you need direct access to the underlying APIs.

## Package Notes

- Firestore and Storage support come from `fire_api` / `fire_api_dart`.
- Messaging uses the Firebase Cloud Messaging v1 API.
- Cloud Tasks uses authenticated HTTP tasks with OIDC tokens when possible.
- Event helpers are designed for `shelf`-based backends.

## License

See [LICENSE](LICENSE).
