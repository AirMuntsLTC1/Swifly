import 'app_config.dart';

/// Supabase connection values.
///
/// They are NOT typed in here. The GitHub Actions build reads them from your
/// repository secrets (SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY) and passes
/// them in with --dart-define. See .github/workflows/build-apk.yml.
///
/// For a local test build you can also pass them yourself:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxx
///
/// The publishable key is safe inside the app. Never put the service_role key here.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://YOUR-PROJECT-REF.supabase.co',
);

const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'YOUR-PUBLISHABLE-KEY',
);

bool get kSupabaseConfigured =>
    kSupabaseUrl.startsWith('https://') &&
    !kSupabaseUrl.contains('YOUR-PROJECT-REF') &&
    kSupabaseAnonKey.isNotEmpty &&
    !kSupabaseAnonKey.startsWith('YOUR-');

/// Sign in is shown only when it is switched on AND Supabase is filled in.
bool get kAuthEnabled => kRequireLogin && kSupabaseConfigured;
