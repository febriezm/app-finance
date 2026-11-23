import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase secara aman (graceful fallback ke SQLite jika offline/unconfigured)
  await SupabaseService.init();

  runApp(
    const ProviderScope(
      child: MyFinanceApp(),
    ),
  );
}
