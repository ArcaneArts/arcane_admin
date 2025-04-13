import 'dart:convert';

import 'package:arcane_admin/arcane_admin.dart';
import 'package:googleapis/cloudtasks/v2.dart' as tasks;

class $AACloudTasks {
  final String region;
  final tasks.CloudTasksApi api;

  $AACloudTasks(this.api, {this.region = "us-central1"});

  /// Schedules a cloud task post request to hit the given url with the given body.
  Future<String?> scheduleTask({
    required String queue,
    required String url,
    required Map<String, dynamic> body,
    DateTime? scheduleTime,
  }) async => api.projects.locations.queues.tasks
      .create(
        tasks.CreateTaskRequest(
          task: tasks.Task(
            scheduleTime:
                scheduleTime == null
                    ? DateTime.timestamp().toIso8601String()
                    : scheduleTime.toUtc().toIso8601String(),
            httpRequest: tasks.HttpRequest(
              oidcToken: tasks.OidcToken(
                audience: url,
                serviceAccountEmail: ArcaneAdmin.serviceAccountEmail,
              ),
              httpMethod: 'POST',
              url: url,
              body: base64Encode(utf8.encode(jsonEncode({...body}))),
              headers: {'Content-Type': 'application/json'},
            ),
          ),
          responseView: "FULL",
        ),
        'projects/${ArcaneAdmin.projectId}/locations/$region/queues/$queue',
      )
      .then((i) => i.name);
}
