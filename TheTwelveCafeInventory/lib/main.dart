import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = String.fromEnvironment('SUPABASE_URL');
  const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final key = publishableKey.isNotEmpty ? publishableKey : legacyKey;

  if (url.isEmpty || key.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Set SUPABASE_URL and either SUPABASE_PUBLISHABLE_KEY or SUPABASE_ANON_KEY using --dart-define.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Supabase.initialize(url: url, publishableKey: key);
  runApp(const TwelveApp());
}
