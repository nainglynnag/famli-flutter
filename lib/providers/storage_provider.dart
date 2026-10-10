import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/storage/image_storage_service.dart';

/// Riverpod provider for the active ImageStorageService instance.
/// Easily configurable via STORAGE_PROVIDER in .env or compile flags.
final imageStorageServiceProvider = Provider<ImageStorageService>((ref) {
  if (Env.useS3Storage) {
    return const S3StorageService(
      bucket: Env.s3Bucket,
      region: Env.s3Region,
      endpoint: Env.s3Endpoint,
    );
  }

  // Default to local storage implementation
  return const LocalStorageService();
});
