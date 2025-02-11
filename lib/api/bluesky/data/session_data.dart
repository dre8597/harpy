import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

part 'session_data.freezed.dart';

@freezed
class SessionData with _$SessionData {
  const factory SessionData({
    required String accessJwt,
    required String refreshJwt,
    required String did,
    required String handle,
  }) = _SessionData;

  const SessionData._();

  /// Checks if the session is about to expire within the given threshold.
  /// Default threshold is 5 minutes.
  bool isNearExpiry({Duration threshold = const Duration(minutes: 5)}) {
    try {
      final decodedToken = JwtDecoder.decode(accessJwt);
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(
        (decodedToken['exp'] as int? ?? 0) * 1000,
      );
      final now = DateTime.now();
      return expiryDate.difference(now) <= threshold;
    } catch (e) {
      // If we can't decode the token, assume it's expired
      return true;
    }
  }

  /// Checks if the session is completely expired
  bool isExpired() {
    try {
      return JwtDecoder.isExpired(accessJwt);
    } catch (e) {
      // If we can't decode the token, assume it's expired
      return true;
    }
  }

  /// Checks if the refresh token is expired
  bool isRefreshExpired() {
    try {
      return JwtDecoder.isExpired(refreshJwt);
    } catch (e) {
      // If we can't decode the token, assume it's expired
      return true;
    }
  }
}
