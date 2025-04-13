# arcane_admin

Simply call 

```dart
void main() {
  await ArcaneAdmin.initialize();
}
```

# Firestore

This uses [fire_api](https://pub.dev/packages/fire_api) under the hood. View that documentation on how to use firestore for more information.

```dart
void main() async {
  DocumentSnapshot snap = await ArcaneAdmin.collection("user").doc("dan").get();
  print(snap.exists ? snap.data : "No data");
}
```

# Cloud Storage

This also uses [fire_api](https://pub.dev/packages/fire_api#firebase-storage-api) view the storage section for more details.

```dart
void main() async {
  FireStorageRef r = Arcane.ref("some/file");

  Future<Uint8List> read = r.read();
  Future<void> written = r.write(Uint8List);
}
```