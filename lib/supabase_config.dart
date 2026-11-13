import 'app_config.dart';

/// Paste your NEW Supabase project values here.
/// Supabase dashboard -> Project Settings -> API:
///   Project URL      -> kSupabaseUrl
///   anon / public key -> kSupabaseAnonKey   (safe to put in the app; never the service_role key)
const String kSupabaseUrl = 'https://YOUR-PROJECT-REF.supabase.co';
const String kSupabaseAnonKey = 'YOUR-ANON-KEY';

bool get kSupabaseConfigured =>
    kSupabaseUrl.startsWith('https://') &&
    !kSupabaseUrl.contains('YOUR-PROJECT-REF') &&
    kSupabaseAnonKey.isNotEmpty &&
    !kSupabaseAnonKey.startsWith('YOUR-');

/// Sign in is shown only when it is switched on AND Supabase is filled in.
/// Until then the app opens straight to Home like before.
bool get kAuthEnabled => kRequireLogin && kSupabaseConfigured;
