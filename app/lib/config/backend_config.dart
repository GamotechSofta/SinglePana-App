import 'api_config.dart';

/// Same as [frontend/src/config/api.js] `BACKEND_BASE_URL` (origin without `/api/v1`).
String get kBackendBaseUrl {
  final api = kApiBaseUrl;
  final stripped = api.replaceAll(RegExp(r'/api/v1/?$'), '');
  return stripped.isEmpty ? api : stripped;
}
