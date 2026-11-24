import 'package:jejaku/features/api/authenticated_dio.dart';
import 'package:jejaku/features/friends/services/social_api.dart';
import 'package:jejaku/features/friends/states/friends_controller.dart';

/// Wires the app to a real social service.
socialApiOverride({required String baseUrl}) {
  return socialApiProvider.overrideWith(
    (ref) => SocialApi(dio: authenticatedDio(ref, baseUrl: baseUrl)),
  );
}
