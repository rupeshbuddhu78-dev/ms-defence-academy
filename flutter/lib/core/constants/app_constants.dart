class AppConstants {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ms-defence-academy-backend.onrender.com/api',
  );
  static const academyName = 'MS Defence Academy';
  static const academyTagline = 'Discipline • Dedication • Success';
}
