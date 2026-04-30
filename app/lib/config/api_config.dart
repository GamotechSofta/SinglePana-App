/// Same base as [frontend/src/config/api.js] (`VITE_API_BASE_URL` / production default).
///
/// Override: `flutter run --dart-define=API_BASE_URL=http://localhost:3010/api/v1`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.shribalaji.live/api/v1',
);
