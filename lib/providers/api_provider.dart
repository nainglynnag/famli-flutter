import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/api_client.dart';
import '../core/firebase_api_client.dart';

/// Single swap point between the REST backend and Firebase.
///
/// FirebaseApiClient implements ApiClient's interface, so every screen and
/// provider is unaffected by this choice. Both backends stay runnable during
/// cutover: build with --dart-define=BACKEND=rest to go back to the Express
/// API in daily-buddies/api.
final apiClientProvider = Provider<ApiClient>(
  (ref) => Env.useFirebaseBackend ? FirebaseApiClient() : ApiClient(),
);
