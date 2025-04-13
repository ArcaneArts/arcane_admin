library arcane_admin;

import 'dart:convert';
import 'dart:io';

import 'package:arcane_admin/messaging.dart';
import 'package:arcane_admin/tasks.dart';
import 'package:arcane_admin/validation.dart';
import 'package:fast_log/fast_log.dart';
import 'package:fire_api/fire_api.dart';
import 'package:fire_api_dart/fire_api_dart.dart';
import 'package:google_cloud/google_cloud.dart';
import 'package:googleapis/cloudtasks/v2.dart';
import 'package:googleapis/fcm/v1.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:googleapis/identitytoolkit/v1.dart' as idtk;
import 'package:googleapis/storage/v1.dart' as s;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:precision_stopwatch/precision_stopwatch.dart';

export 'package:fire_api/fire_api.dart';

class ArcaneAdmin {
  ArcaneAdmin._();

  static late final String projectId;
  static late final FireStorage storage;
  static late final FirestoreDatabase firestore;
  static late final $AAMessaging messaging;
  static late final $AAValidation validation;
  static late final $AACloudTasks tasks;
  static late final String defaultStorageBucket;
  static late final AGClient agclient;

  static String? get serviceAccountEmail => agclient.serviceAccountEmail;
  static http.Client get client => agclient.client;
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
  static Future<void> initialize({
    String? defaultStorageBucket,
    String database = "(default)",
    String? apiKey,
    ServiceAccountCredentials? credentials,
    String? projectId,
    String cloudTasksRegion = "us-central1",
    String firestoreBasePath = "",
    String firestoreBaseUrl = "https://firestore.googleapis.com/",
  }) async {
    PrecisionStopwatch p = PrecisionStopwatch();
    await Future.wait([
      if (projectId == null) computeProjectId().then((i) => projectId = i),
      GoogleClientFactory.googleClient(
        apiKey: apiKey,
        credentials: credentials,
        scopes: [
          CloudTasksApi.cloudPlatformScope,
          idtk.IdentityToolkitApi.firebaseScope,
          FirestoreApi.datastoreScope,
          s.StorageApi.devstorageReadWriteScope,
        ],
      ).then((i) => agclient = i),
    ]);

    ArcaneAdmin.defaultStorageBucket =
        defaultStorageBucket ?? "$projectId.firebasestorage.app";
    ArcaneAdmin.projectId = projectId!;
    info("Initialized Arcane Admin in ${p.getMilliseconds().ceil()}ms");
    if (serviceAccountEmail != null) {
      info("Service Account: $serviceAccountEmail");
    } else {
      warn(
        "Service Account not found! This will still work however we cannot validate JWT requests from cloud tasks!",
      );
    }

    validation = $AAValidation();
    messaging = $AAMessaging(FirebaseCloudMessagingApi(client));
    tasks = $AACloudTasks(CloudTasksApi(client), region: cloudTasksRegion);
    storage = GoogleCloudFireStorage(s.StorageApi(client));
    firestore = GoogleCloudFirestoreDatabase(
      FirestoreApi(
        client,
        rootUrl: firestoreBaseUrl,
        servicePath: firestoreBasePath,
      ),
      projectId!,
      database: database,
    );
  }
}

class AGClient {
  final http.Client client;
  final String? serviceAccountEmail;

  AGClient(this.client, this.serviceAccountEmail);
}

class GoogleClientFactory {
  static Future<AGClient> googleClient({
    List<String> scopes = const [],
    String? apiKey,
    ServiceAccountCredentials? credentials,
  }) async {
    if (apiKey != null) {
      http.Client c = clientViaApiKey(apiKey);
      return AGClient(c, null);
    } else if (credentials != null) {
      http.Client c = await clientViaServiceAccount(credentials, scopes);
      return AGClient(c, credentials.email);
    } else {
      http.Client c = await clientViaApplicationDefaultCredentials(
        scopes: scopes,
      );
      String? email = await findServiceAccountEmailFromADC();
      return AGClient(c, email);
    }
  }

  static Future<String?> tryParseServiceAccountEmail(File file) async {
    if (!await file.exists()) {
      return null;
    }

    try {
      String content = await file.readAsString();
      Map<String, dynamic> map = jsonDecode(content);

      if (map['type'] == 'service_account' && map['client_email'] is String) {
        return map['client_email'] as String;
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> tryFetchEmailFromMetadata() async {
    const String metadataUrl =
        'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email';
    try {
      http.Response response = await http.get(
        Uri.parse(metadataUrl),
        headers: {'Metadata-Flavor': 'Google'},
      );
      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> findServiceAccountEmailFromADC() async {
    String? credsEnv = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
    if (credsEnv != null && credsEnv.isNotEmpty) {
      String? s = await tryParseServiceAccountEmail(File(credsEnv));
      if (s != null) return s;
    }

    File credFile;
    if (Platform.isWindows) {
      String? appData = Platform.environment['APPDATA'];
      if (appData == null || appData.isEmpty) return null;
      credFile = File.fromUri(
        Uri.directory(
          appData,
        ).resolve('gcloud/application_default_credentials.json'),
      );
    } else {
      String? home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return null;
      credFile = File.fromUri(
        Uri.directory(
          home,
        ).resolve('.config/gcloud/application_default_credentials.json'),
      );
    }

    String? email = await tryParseServiceAccountEmail(credFile);
    if (email != null) return email;
    return tryFetchEmailFromMetadata();
  }
}
