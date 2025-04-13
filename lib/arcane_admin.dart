library arcane_admin;

import 'package:fire_api/fire_api.dart';
import 'package:fire_api_dart/fire_api_dart.dart';
import 'package:google_cloud/google_cloud.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:googleapis/storage/v1.dart' as s;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

export 'package:fire_api/fire_api.dart';

class ArcaneAdmin {
  static late final String projectId;
  static late final FireStorage storage;
  static late final FirestoreDatabase firestore;
  static late final String defaultStorageBucket;

  static FireStorageRef bucket([String? b]) =>
      storage.bucket(b ?? defaultStorageBucket);
  static FireStorageRef ref(String path, {String? bucket}) =>
      ArcaneAdmin.bucket(bucket).ref(path);

  static void collection(String collection) => firestore.collection(collection);
  static void document(String documentPAth) => firestore.document(documentPAth);

  /// If apiKey is defined, it will be used instead of credentials.
  /// If credentials is defined, it will be used instead of using the environment.
  /// If the projectId is not defined it will be used from the environment.
  /// The projectId defaults to $projectId.firebasestorage.app, though if you
  /// have the appspot domain actually define your bucket
  Future<void> initialize({
    String? defaultStorageBucket,
    String database = "(default)",
    String? apiKey,
    ServiceAccountCredentials? credentials,
    String? projectId,
    String firestoreBasePath = "",
    String firestoreBaseUrl = "https://firestore.googleapis.com/",
  }) async {
    late http.Client storageClient;
    late http.Client firestoreClient;
    await Future.wait([
      if (projectId == null) computeProjectId().then((i) => projectId = i),
      googleClient(
        apiKey: apiKey,
        credentials: credentials,
        scopes: [s.StorageApi.devstorageReadWriteScope],
      ).then((i) => storageClient = i),
      googleClient(
        apiKey: apiKey,
        credentials: credentials,
        scopes: [FirestoreApi.datastoreScope],
      ).then((i) => firestoreClient = i),
    ]);

    storage = GoogleCloudFireStorage(s.StorageApi(storageClient));
    firestore = GoogleCloudFirestoreDatabase(
      FirestoreApi(
        firestoreClient,
        rootUrl: firestoreBaseUrl,
        servicePath: firestoreBasePath,
      ),
      projectId!,
      database: database,
    );
    ArcaneAdmin.defaultStorageBucket =
        defaultStorageBucket ?? "$projectId.firebasestorage.app";
    ArcaneAdmin.projectId = projectId!;
  }

  Future<http.Client> googleClient({
    List<String> scopes = const [],
    String? apiKey,
    ServiceAccountCredentials? credentials,
  }) async =>
      apiKey != null
          ? clientViaApiKey(apiKey)
          : credentials != null
          ? await clientViaServiceAccount(credentials, scopes)
          : await clientViaApplicationDefaultCredentials(scopes: scopes);
}
