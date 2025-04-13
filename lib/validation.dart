import 'dart:convert';

import 'package:fast_log/fast_log.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:shelf/shelf.dart' as shelf;

class $AAValidation {
  Future<bool> validateGCPRequestJWT(
    shelf.Request request, {
    String? verifyAudience,
  }) async {
    try {
      String? authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        warn("Invalid Authorization header");
        return false;
      }

      String token = authHeader.substring('Bearer '.length);
      JsonWebSignature jws;
      try {
        jws = JsonWebSignature.fromCompactSerialization(token);
      } catch (_) {
        warn("Invalid JWT, could not parse");
        return false;
      }

      JoseHeader commonProtected = jws.commonProtectedHeader;
      String? kid = commonProtected.keyId;

      if (kid == null) {
        warn("Invalid JWT, no kid");
        return false;
      }

      Map<String, JsonWebKey> jwks = await _fetchGoogleCerts();
      JsonWebKey? publicKey = jwks[kid];
      if (publicKey == null) {
        warn("Invalid JWT, no public key cant verify right key");
        return false;
      }

      if (jws.recipients.isEmpty) {
        warn("Invalid JWT, no recipients.");
        return false;
      }
      JoseRecipient recipient = jws.recipients[0];
      List<int>? verifiedPayloadBytes = jws.getPayloadFor(
        publicKey,
        commonProtected,
        recipient,
      );

      if (verifiedPayloadBytes == null) {
        // That means signature validation failed.
        warn("Invalid JWT, signature validation failed");
        return false;
      }

      Map<String, dynamic> payload = jws.unverifiedPayload.jsonContent;
      String? issuer = payload['iss'] as String?;

      if (issuer != 'accounts.google.com' &&
          issuer != 'https://accounts.google.com') {
        warn(
          "Invalid JWT, invalid issuer. $issuer is not accounts.google.com or https://accounts.google.com.",
        );
        return false;
      }

      if (verifyAudience != null) {
        String? audience = payload['aud'] as String?;
        if (verifyAudience != audience) {
          warn(
            "Invalid JWT, invalid audience. Expected $verifyAudience but got $audience",
          );
          return false;
        }
      }

      dynamic expValue = payload['exp'];

      if (expValue is! int) {
        warn("Invalid JWT, invalid exp type");
        return false;
      }

      int exp = expValue;
      int nowInSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (exp < nowInSeconds) {
        warn("Invalid JWT, expired $exp < $nowInSeconds");
        return false;
      }
      return true;
    } catch (e, es) {
      warn(
        "Encountered an exception while trying to verify JWT, so we cant verify.",
      );
      error("Failed to verify JWT: $e");
      error(es);
      return false;
    }
  }

  Map<String, JsonWebKey>? _cachedCerts;
  DateTime? _cacheExpiry;

  Future<Map<String, JsonWebKey>> _fetchGoogleCerts() async {
    if (_cachedCerts != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedCerts!;
    }

    http.Response response = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v3/certs'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Google certs: ${response.statusCode}');
    }

    String? cacheControl = response.headers['cache-control'];
    Duration maxAge = const Duration(seconds: 0);
    if (cacheControl != null) {
      RegExpMatch? match = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (match != null) {
        int seconds = int.parse(match.group(1)!);
        maxAge = Duration(seconds: seconds);
      }
    }

    Map<String, dynamic> body = jsonDecode(response.body);
    Map<String, JsonWebKey> jwks = {};
    List<dynamic> keysList = body['keys'];
    for (dynamic k in keysList) {
      JsonWebKey jwk = JsonWebKey.fromJson(k as Map<String, dynamic>);
      if (jwk.keyId != null) {
        jwks[jwk.keyId!] = jwk;
      }
    }

    _cachedCerts = jwks;
    _cacheExpiry = DateTime.now().add(maxAge);

    return jwks;
  }
}
