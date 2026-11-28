import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/vocab_assistant_datasource.dart';
import '../auth/auth_provider.dart';

/// AI list-creation assistance (translate / themed suggestions).
final vocabAssistantProvider = Provider<VocabAssistantDataSource>(
  (ref) => VocabAssistantDataSource(ref.watch(supabaseClientProvider)),
);
