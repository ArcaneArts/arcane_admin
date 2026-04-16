import 'dart:convert';
import 'dart:math';

import 'package:arcane_admin/arcane_admin.dart';
import 'package:artifact/artifact.dart';
import 'package:fast_log/fast_log.dart';
import 'package:precision_stopwatch/precision_stopwatch.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:toxic/extensions/iterable.dart';

class TaskManager {
  /// I.e. barbequeue
  final String queue;

  /// I.e. https://some-server-1234.us-regionX.run.app/event/executeJob
  /// You will need to handle it with Router()..taskManager(THIS OBJECT)
  /// where the router is handling /event. This will add the /executeJob
  /// or whatever your trailing slash is as a new post request route to this router
  final String endpointUrl;
  final List<TaskExecutor> executors;
  final Duration executionBlockTime;

  const TaskManager({
    required this.queue,
    required this.endpointUrl,
    required this.executors,
    this.executionBlockTime = const Duration(minutes: 5),
  });

  TaskExecutor? executorForTask(ExecutableTask task) =>
      executors.select((t) => t.isCompatible(task));

  Future<void> schedule(
    ExecutableTask task, {
    int? lbms,
    Duration delay = const Duration(seconds: 1),
  }) {
    TaskExecutor? executor = executorForTask(task);

    if (executor == null) {
      throw Exception(
        "No executor found for task ${task.taskId} type ${task.runtimeType}",
      );
    }

    return ArcaneAdmin.tasks.scheduleTask(
      scheduleTime: DateTime.timestamp().add(delay),
      queue: queue,
      url: endpointUrl,
      body: {
        "lbms": lbms,
        "executor": executor.typeId,
        "task": ArtifactAccessor.all
            .select((t) => t.isArtifact(task))!
            .artifactToMap(task),
      },
    );
  }

  Future<Response> handleTaskJob(Request request) async {
    try {
      Map<String, dynamic> body = jsonDecode(await request.readAsString());
      String executorId = body["executor"];
      Map<String, dynamic> taskData = body["task"];
      TaskExecutor? executor = executors.select((t) => t.typeId == executorId);
      ExecutableTask task = executor!.deserialize(taskData);
      int lastBackoffMS = body["lbms"] ?? 0;

      TaskExecutionContext context = TaskExecutionContext(
        task: task,
        started: DateTime.timestamp(),
        timeBlockLimit: executionBlockTime,
        stopwatch: PrecisionStopwatch.start(),
      );

      while (context.running && context.hasTimeRemaining && !context.backing) {
        await task.workOnTask(context);
      }

      if (context.running) {
        if (context.backing) {
          lastBackoffMS = max(
            context.lastBack?.inMilliseconds ?? 0,
            lastBackoffMS,
          );
        } else {
          lastBackoffMS = (lastBackoffMS * 0.7).floor();
        }

        success(
          "Task ${task.taskId} handed off to continue working (exceeded ${executionBlockTime.inSeconds}s)",
        );
        await schedule(
          task,
          lbms: lastBackoffMS,
          delay: Duration(seconds: 5) + Duration(milliseconds: lastBackoffMS),
        );
      }
    } catch (e, es) {
      error(
        "Task handle failure! $e $es. Responding OK to not poison retries. If you want your task to retry then catch your errors.",
      );
    }

    return Response.ok("");
  }
}

class TaskExecutionContext {
  final DateTime started;
  final Duration timeBlockLimit;
  final PrecisionStopwatch stopwatch;
  bool running = true;
  Duration? lastBack;
  bool backing = false;

  final ExecutableTask task;

  TaskExecutionContext({
    required this.task,
    required this.timeBlockLimit,
    required this.started,
    required this.stopwatch,
  });

  Duration get elapsedTime =>
      Duration(microseconds: (stopwatch.getMilliseconds() * 1000).round());

  Duration get remainingTime {
    Duration remaining = timeBlockLimit - elapsedTime;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasTimeRemaining => remainingTime > Duration.zero;

  void _stop() {
    running = false;
  }

  void backoff() {
    backing = true;
    int bms = lastBack?.inMilliseconds ?? 0;
    bms = max(5000, bms);
    bms *= 2;
    lastBack = Duration(milliseconds: bms);
    warn("Backing off ${task.taskId} for ${lastBack!.inSeconds} seconds");
  }

  void complete() {
    _stop();
    success("Task ${task.taskId} completed successfully");
  }

  void fail(String err) {
    _stop();
    error("Task ${task.taskId} aborted with error: $err");
  }
}

class TaskExecutor<T extends ExecutableTask> {
  final String typeId;

  const TaskExecutor({required this.typeId});

  bool isCompatible(ExecutableTask task) => T == task.runtimeType;

  T deserialize(Map<String, dynamic> data) => ArtifactAccessor.all
      .select((a) => a.isArtifact(T))!
      .artifactFromMap(data);
}

mixin ExecutableTask {
  String get taskId;

  Future<void> workOnTask(TaskExecutionContext context);
}

extension XRouter on Router {
  void taskManager(TaskManager tm) {
    String tag = "/${tm.endpointUrl.split("/").last}";
    post(tag, tm.handleTaskJob);
  }
}
