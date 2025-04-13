import 'dart:async';

import 'package:arcane_admin/arcane_admin.dart';
import 'package:googleapis/fcm/v1.dart' as fmc1;

class ArcaneAdminMessaging {
  final fmc1.FirebaseCloudMessagingApi api;

  ArcaneAdminMessaging(this.api);

  Future<void> send(FMessage message) => api.projects.messages.send(
    fmc1.SendMessageRequest(message: message.toModel(), validateOnly: false),
    'projects/${ArcaneAdmin.projectId}',
  );

  Future<void> sendMulticast(FMulticastMessage message) => sendAll(
    message.tokens
        .map(
          (token) => FTokenMessage(
            token: token,
            data: message.data,
            notification: message.notification,
            android: message.android,
            apns: message.apns,
            fcmOptions: message.fcmOptions,
            webpush: message.webpush,
          ),
        )
        .toList(),
  );

  Future<void> sendAll(List<FMessage> messages) async {
    if (messages.isEmpty) {
      throw Exception('messages must be a non-empty array');
    }
    if (messages.length > _fmcMaxBatchSize) {
      throw Exception(
        'messages list must not contain more than $_fmcMaxBatchSize items',
      );
    }

    await Future.wait(
      messages.map(
        (message) async => api.projects.messages.send(
          fmc1.SendMessageRequest(
            message: message.toModel(),
            validateOnly: false,
          ),
          'projects/${ArcaneAdmin.projectId}',
        ),
      ),
    );
  }
}

const _fmcMaxBatchSize = 500;

abstract class FBaseMessage {
  FBaseMessage._({
    this.data,
    this.notification,
    this.android,
    this.webpush,
    this.apns,
    this.fcmOptions,
  });

  final Map<String, String>? data;
  final FNotification? notification;
  final FAndroidConfig? android;
  final FWebpushConfig? webpush;
  final FApnsConfig? apns;
  final FFcmOptions? fcmOptions;
}

sealed class FMessage extends FBaseMessage {
  FMessage._({
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._();

  fmc1.Message toModel();
}

class FTokenMessage extends FMessage {
  FTokenMessage({
    required this.token,
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._();

  final String token;

  @override
  fmc1.Message toModel() {
    return fmc1.Message(
      data: data,
      notification: notification?.toModel(),
      android: android?.toModel(),
      webpush: webpush?.toModel(),
      apns: apns?.toModel(),
      fcmOptions: fcmOptions?.toModel(),
      token: token,
    );
  }
}

class FTopicMessage extends FMessage {
  FTopicMessage({
    required this.topic,
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._();

  final String topic;

  @override
  fmc1.Message toModel() {
    return fmc1.Message(
      data: data,
      notification: notification?.toModel(),
      android: android?.toModel(),
      webpush: webpush?.toModel(),
      apns: apns?.toModel(),
      fcmOptions: fcmOptions?.toModel(),
      topic: topic,
    );
  }
}

class FConditionMessage extends FMessage {
  FConditionMessage({
    required this.condition,
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._();

  final String condition;

  @override
  fmc1.Message toModel() {
    return fmc1.Message(
      data: data,
      notification: notification?.toModel(),
      android: android?.toModel(),
      webpush: webpush?.toModel(),
      apns: apns?.toModel(),
      fcmOptions: fcmOptions?.toModel(),
      condition: condition,
    );
  }
}

class FMulticastMessage extends FBaseMessage {
  FMulticastMessage({
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
    required this.tokens,
  }) : super._();

  final List<String> tokens;
}

class FNotification {
  FNotification({this.title, this.body, this.imageUrl});

  final String? title;
  final String? body;
  final String? imageUrl;

  fmc1.Notification toModel() {
    return fmc1.Notification(title: title, body: body, image: imageUrl);
  }
}

class FFcmOptions {
  FFcmOptions({this.analyticsLabel});

  final String? analyticsLabel;

  fmc1.FcmOptions toModel() {
    return fmc1.FcmOptions(analyticsLabel: analyticsLabel);
  }
}

class FWebpushConfig {
  FWebpushConfig({this.headers, this.data, this.notification, this.fcmOptions});

  final Map<String, String>? headers;
  final Map<String, String>? data;
  final FWebpushNotification? notification;
  final FWebpushFcmOptions? fcmOptions;

  fmc1.WebpushConfig toModel() {
    return fmc1.WebpushConfig(
      headers: headers,
      data: data,
      notification: notification?.toModel(),
      fcmOptions: fcmOptions?.toModel(),
    );
  }
}

class FWebpushFcmOptions {
  FWebpushFcmOptions({this.link});

  final String? link;

  fmc1.WebpushFcmOptions toModel() {
    return fmc1.WebpushFcmOptions(link: link);
  }
}

class FWebpushNotificationAction {
  FWebpushNotificationAction({
    required this.action,
    this.icon,
    required this.title,
  });

  final String action;
  final String? icon;
  final String title;

  Map<String, Object?> toModel() {
    return {'action': action, 'icon': icon, 'title': title}.cleanBools();
  }
}

extension on Map<String, Object?> {
  Map<String, Object?> cleanBools() {
    for (final entry in entries) {
      switch (entry.value) {
        case true:
          this[entry.key] = 1;
        case false:
          this[entry.key] = 0;
      }
    }

    return this;
  }
}

enum FWebpushNotificationDirection { auto, ltr, rtl }

class FWebpushNotification {
  FWebpushNotification({
    this.title,
    this.customData,
    this.actions,
    this.badge,
    this.body,
    this.data,
    this.dir,
    this.icon,
    this.image,
    this.lang,
    this.renotify,
    this.requireInteraction,
    this.silent,
    this.tag,
    this.timestamp,
    this.vibrate,
  });

  final String? title;
  final List<FWebpushNotificationAction>? actions;
  final String? badge;
  final String? body;
  final Object? data;
  final FWebpushNotificationDirection? dir;
  final String? icon;
  final String? image;
  final String? lang;
  final bool? renotify;
  final bool? requireInteraction;
  final bool? silent;
  final String? tag;
  final int? timestamp;
  final List<num>? vibrate;
  final Map<String, Object?>? customData;

  Map<String, Object?> toModel() {
    return {
      'title': title,
      'actions': actions?.map((a) => a.toModel()).toList(),
      'badge': badge,
      'body': body,
      'data': data,
      'dir': dir?.toString().split('.').last,
      'icon': icon,
      'image': image,
      'lang': lang,
      'renotify': renotify,
      'requireInteraction': requireInteraction,
      'silent': silent,
      'tag': tag,
      'timestamp': timestamp,
      'vibrate': vibrate,
      if (customData case final customData?) ...customData,
    }.cleanBools();
  }
}

class FApnsConfig {
  FApnsConfig({this.headers, this.payload, this.fcmOptions});

  final Map<String, String>? headers;
  final FApnsPayload? payload;
  final FApnsFcmOptions? fcmOptions;

  fmc1.ApnsConfig toModel() {
    return fmc1.ApnsConfig(
      headers: headers,
      payload: payload?.toModel(),
      fcmOptions: fcmOptions?.toModel(),
    );
  }
}

class FApnsPayload {
  FApnsPayload({required this.aps, this.customData});

  final FAps aps;

  final Map<String, String>? customData;

  Map<String, Object?> toModel() {
    return {
      'aps': aps.toModel(),
      if (customData case final customData?) ...customData,
    }.cleanBools();
  }
}

class FAps {
  FAps({
    this.alert,
    this.badge,
    this.sound,
    this.contentAvailable,
    this.mutableContent,
    this.category,
    this.threadId,
    this.interruptionLevel,
  });

  final FApsAlert? alert;
  final num? badge;
  final bool? contentAvailable;
  final bool? mutableContent;
  final String? category;
  final String? threadId;
  final String? interruptionLevel;
  final String? sound;

  Map<String, Object?> toModel() {
    return {
      if (alert != null) 'alert': alert?.toModel(),
      if (badge != null) 'badge': badge,
      if (sound != null) 'sound': sound,
      if (contentAvailable != null) 'content-available': contentAvailable,
      if (mutableContent != null) 'mutable-content': mutableContent,
      if (category != null) 'category': category,
      if (threadId != null) 'thread-id': threadId,
      if (interruptionLevel != null) 'interruption-level': interruptionLevel,
    }.cleanBools();
  }
}

class FApsAlert {
  FApsAlert({
    this.title,
    this.subtitle,
    this.body,
    this.locKey,
    this.locArgs,
    this.titleLocKey,
    this.titleLocArgs,
    this.subtitleLocKey,
    this.subtitleLocArgs,
    this.actionLocKey,
    this.launchImage,
  });

  final String? title;
  final String? subtitle;
  final String? body;
  final String? locKey;
  final List<String>? locArgs;
  final String? titleLocKey;
  final List<String>? titleLocArgs;
  final String? subtitleLocKey;
  final List<String>? subtitleLocArgs;
  final String? actionLocKey;
  final String? launchImage;

  Map<String, Object?> toModel() {
    return {
      'title': title,
      'subtitle': subtitle,
      'body': body,
      'loc-key': locKey,
      'loc-args': locArgs,
      'title-loc-key': titleLocKey,
      'title-loc-args': titleLocArgs,
      'subtitle-loc-key': subtitleLocKey,
      'subtitle-loc-args': subtitleLocArgs,
      'action-loc-key': actionLocKey,
      'launch-image': launchImage,
    }.cleanBools();
  }
}

class FApnsFcmOptions {
  FApnsFcmOptions({this.analyticsLabel, this.imageUrl});

  final String? analyticsLabel;
  final String? imageUrl;

  fmc1.ApnsFcmOptions toModel() {
    return fmc1.ApnsFcmOptions(analyticsLabel: analyticsLabel, image: imageUrl);
  }
}

enum AndroidConfigPriority { high, normal }

class FAndroidConfig {
  FAndroidConfig({
    this.collapseKey,
    this.priority,
    this.ttl,
    this.restrictedPackageName,
    this.data,
    this.notification,
    this.fcmOptions,
  });

  final String? collapseKey;
  final AndroidConfigPriority? priority;
  final String? ttl;
  final String? restrictedPackageName;
  final Map<String, String>? data;
  final FAndroidNotification? notification;
  final FAndroidFcmOptions? fcmOptions;

  fmc1.AndroidConfig toModel() {
    return fmc1.AndroidConfig(
      collapseKey: collapseKey,
      priority: priority?.toString().split('.').last,
      ttl: ttl,
      restrictedPackageName: restrictedPackageName,
      data: data,
      notification: notification?.toModel(),
      fcmOptions: fcmOptions?.toModel(),
    );
  }
}

enum FAndroidNotificationPriority {
  min('PRIORITY_MIN'),
  low('PRIORITY_LOW'),
  $default('PRIORITY_DEFAULT'),
  high('PRIORITY_HIGH'),
  max('PRIORITY_MAX');

  const FAndroidNotificationPriority(this._code);
  final String _code;
}

enum AndroidNotificationVisibility { private, public, secret }

class FAndroidNotification {
  FAndroidNotification({
    this.title,
    this.body,
    this.icon,
    this.color,
    this.sound,
    this.tag,
    this.imageUrl,
    this.clickAction,
    this.bodyLocKey,
    this.bodyLocArgs,
    this.titleLocKey,
    this.titleLocArgs,
    this.channelId,
    this.ticker,
    this.sticky,
    this.eventTimestamp,
    this.localOnly,
    this.priority,
    this.vibrateTimingsMillis,
    this.defaultVibrateTimings,
    this.defaultSound,
    this.lightSettings,
    this.defaultLightSettings,
    this.visibility,
    this.notificationCount,
  });

  final String? title;
  final String? body;
  final String? icon;
  final String? color;
  final String? sound;
  final String? tag;
  final String? imageUrl;
  final String? clickAction;
  final String? bodyLocKey;
  final List<String>? bodyLocArgs;
  final String? titleLocKey;
  final List<String>? titleLocArgs;
  final String? channelId;
  final String? ticker;
  final bool? sticky;
  final DateTime? eventTimestamp;
  final bool? localOnly;
  final FAndroidNotificationPriority? priority;
  final List<String>? vibrateTimingsMillis;
  final bool? defaultVibrateTimings;
  final bool? defaultSound;
  final FLightSettings? lightSettings;
  final bool? defaultLightSettings;
  final AndroidNotificationVisibility? visibility;
  final int? notificationCount;

  fmc1.AndroidNotification toModel() {
    return fmc1.AndroidNotification(
      title: title,
      body: body,
      icon: icon,
      color: color,
      sound: sound,
      tag: tag,
      image: imageUrl,
      clickAction: clickAction,
      bodyLocKey: bodyLocKey,
      bodyLocArgs: bodyLocArgs,
      titleLocKey: titleLocKey,
      titleLocArgs: titleLocArgs,
      channelId: channelId,
      ticker: ticker,
      sticky: sticky,
      eventTime: eventTimestamp?.toUtc().toIso8601String(),
      localOnly: localOnly,
      notificationPriority: priority?._code,
      vibrateTimings: vibrateTimingsMillis,
      defaultVibrateTimings: defaultVibrateTimings,
      defaultSound: defaultSound,
      lightSettings: lightSettings?.toModel(),
      defaultLightSettings: defaultLightSettings,
      visibility: visibility?.toString().split('.').last,
      notificationCount: notificationCount,
    );
  }
}

class FLightSettings {
  FLightSettings({
    required this.color,
    required this.lightOnDurationMillis,
    required this.lightOffDurationMillis,
  });

  final ({double? red, double? blue, double? green, double? alpha}) color;
  final String lightOnDurationMillis;
  final String lightOffDurationMillis;

  fmc1.LightSettings toModel() {
    return fmc1.LightSettings(
      color: fmc1.Color(
        red: color.red,
        green: color.green,
        blue: color.blue,
        alpha: color.alpha,
      ),
      lightOnDuration: lightOnDurationMillis,
      lightOffDuration: lightOffDurationMillis,
    );
  }
}

class FAndroidFcmOptions {
  FAndroidFcmOptions({this.analyticsLabel});

  final String? analyticsLabel;

  fmc1.AndroidFcmOptions toModel() {
    return fmc1.AndroidFcmOptions(analyticsLabel: analyticsLabel);
  }
}
