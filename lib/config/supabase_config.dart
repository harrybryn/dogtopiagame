/// Supabase project configuration.
///
/// Paste your Supabase Anon / Publishable key below (from Supabase Dashboard ->
/// Project Settings -> API), or pass it at build/run time via:
/// `--dart-define=SUPABASE_ANON_KEY=your_key_here`
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String mobileRedirectUrl =
      'io.supabase.dogtopia://login-callback/';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'PASTE_YOUR_SUPABASE_ANON_KEY_HERE';
}
