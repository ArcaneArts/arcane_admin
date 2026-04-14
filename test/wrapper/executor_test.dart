import 'dart:convert';

import 'package:arcane_admin/wrapper/executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

void main() {
  group('TaskManager.handleTaskJob', () {
    test(
      'propagates computed backoff milliseconds when rescheduling',
      () async {
        _TestTaskManager manager = _TestTaskManager();
        Request request = Request(
          'POST',
          Uri.parse('https://example.com/executeJob'),
          body: jsonEncode({
            'executor': 'test',
            'task': <String, dynamic>{},
            'lbms': 5000,
          }),
        );

        Response response = await manager.handleTaskJob(request);

        expect(response.statusCode, 200);
        expect(manager.scheduledLbms, 10000);
        expect(manager.scheduledDelay, const Duration(seconds: 15));
      },
    );

    test(
      'retains larger incoming backoff when it already exceeds local backoff',
      () async {
        _TestTaskManager manager = _TestTaskManager();
        Request request = Request(
          'POST',
          Uri.parse('https://example.com/executeJob'),
          body: jsonEncode({
            'executor': 'test',
            'task': <String, dynamic>{},
            'lbms': 30000,
          }),
        );

        Response response = await manager.handleTaskJob(request);

        expect(response.statusCode, 200);
        expect(manager.scheduledLbms, 30000);
        expect(manager.scheduledDelay, const Duration(seconds: 35));
      },
    );
  });
}

class _TestTaskManager extends TaskManager {
  int? scheduledLbms;
  Duration? scheduledDelay;

  _TestTaskManager()
    : super(
        queue: 'queue',
        endpointUrl: 'https://example.com/executeJob',
        executors: const [_BackoffTaskExecutor()],
      );

  @override
  Future<void> schedule(
    ExecutableTask task, {
    int? lbms,
    Duration delay = const Duration(seconds: 1),
  }) async {
    scheduledLbms = lbms;
    scheduledDelay = delay;
  }
}

class _BackoffTaskExecutor extends TaskExecutor<_BackoffTask> {
  const _BackoffTaskExecutor() : super(typeId: 'test');

  @override
  bool isCompatible(ExecutableTask task) => task is _BackoffTask;

  @override
  _BackoffTask deserialize(Map<String, dynamic> data) => _BackoffTask();
}

class _BackoffTask with ExecutableTask {
  @override
  String get taskId => 'task-id';

  @override
  Future<void> workOnTask(TaskExecutionContext context) async {
    context.backoff();
  }
}
