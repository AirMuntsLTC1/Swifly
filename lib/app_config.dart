/// Master switch for test data.
///
/// true  -> the app loads mock users, posts, and simulated live activity
///          (see the lib/mock/ folder).
/// false -> the app starts empty and only shows data from the real database.
const bool kUseMockData = true;



/// true  -> the app starts on Sign in / Register (once lib/supabase_config.dart is filled in).
/// false -> the app opens straight to Home.
const bool kRequireLogin = true;
