import 'dart:convert';

import 'package:arcane_admin/arcane_admin.dart';
import 'package:eventarc/eventarc.dart';
import 'package:eventarc/events/cloud/firestore/v1.dart';
import 'package:shelf/shelf.dart';

typedef $AACloudDocumentEventHandler =
    Future<Response> Function(ArcaneDocumentEvent event);

extension XDocEventRequest on Request {
  Future<Response> documentEvent($AACloudDocumentEventHandler handler) =>
      ArcaneAdmin.events.onDocumentEvent(this, handler);

  Future<Response> storageEvent(
    Future<Response> Function(ArcaneStorageEvent event) handler,
  ) => ArcaneAdmin.events.onStorageEvent(this, handler);
}

class ArcaneStorageEvent {
  final String bucket;
  final String path;
  final String contentType;
  final Map<String, dynamic> metadata;
  final String contentDisposition;
  final int? size;

  const ArcaneStorageEvent({
    required this.bucket,
    required this.path,
    required this.contentType,
    required this.metadata,
    required this.contentDisposition,
    required this.size,
  });

  factory ArcaneStorageEvent.from(Map<String, dynamic> event) {
    return ArcaneStorageEvent(
      bucket: event['bucket'] as String,
      path: event['name'] as String,
      contentType: event['contentType'] as String,
      metadata: event['metadata'] ?? {},
      contentDisposition: event['contentDisposition'] as String,
      size: event['size'] != null ? int.tryParse(event['size']) : null,
    );
  }
}

class ArcaneDocumentEvent {
  final Map<String, String> ids;
  final String documentPath;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final Request request;
  final DocumentEventData rawEventData;

  const ArcaneDocumentEvent({
    required this.ids,
    required this.documentPath,
    required this.before,
    required this.after,
    required this.request,
    required this.rawEventData,
  });
}

class $AACloudEvents {
  Future<DocumentEventData> readDocumentEvent(Request request) async =>
      DocumentEventData.fromBuffer(
        await request.read().expand((element) => element).toList(),
      );

  Future<Response> onStorageEvent(
    Request request,
    Future<Response> Function(ArcaneStorageEvent event) handler,
  ) async {
    Map<String, dynamic> data = jsonDecode(await request.readAsString());
    ArcaneStorageEvent event = ArcaneStorageEvent.from(data);
    return handler(event);
  }

  Future<Response> onDocumentEvent(
    Request request,
    $AACloudDocumentEventHandler handler,
  ) async {
    DocumentEventData data = await readDocumentEvent(request);
    String documentPath = data.documentPath;
    List<String> seg = documentPath.split("/");
    Map<String, String> ids = {};

    for (int i = 0; i < seg.length; i += 2) {
      if (i % 2 == 0 && i + 1 < seg.length) {
        ids[seg[i]] = seg[i + 1];
      }
    }

    return handler(
      ArcaneDocumentEvent(
        ids: ids,
        documentPath: documentPath,
        before: data.hasOldValue() ? data.oldValue.asMap : null,
        after: data.hasValue() ? data.value.asMap : null,
        request: request,
        rawEventData: data,
      ),
    );
  }
}
