import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Clean, modular image storage contract. Easily swappable for S3, Firebase,
/// Cloudflare R2, or local disk without modifying UI or models.
abstract class ImageStorageService {
  /// Saves the user's profile picture and returns the stored reference (path or URL).
  Future<String> saveProfileImage({
    required String userId,
    required Uint8List bytes,
    required String extension,
  });

  /// Deletes the user's stored profile picture.
  Future<void> deleteProfileImage({
    required String userId,
    required String imageRef,
  });
}

/// Local storage implementation:
/// - On mobile/desktop: Writes file to the app documents directory and returns the file path.
/// - On web: Converts to a compressed Base64 data URI so it persists reliably across sessions.
class LocalStorageService implements ImageStorageService {
  const LocalStorageService();

  @override
  Future<String> saveProfileImage({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final cleanExt = extension.replaceAll('.', '').toLowerCase();

    if (kIsWeb) {
      final base64String = base64Encode(bytes);
      return 'data:image/$cleanExt;base64,$base64String';
    }

    final appDir = await getApplicationDocumentsDirectory();
    final profileDir = File('${appDir.path}/profiles');
    if (!profileDir.existsSync()) {
      profileDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${appDir.path}/profiles/${userId}_$timestamp.$cleanExt');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Future<void> deleteProfileImage({
    required String userId,
    required String imageRef,
  }) async {
    if (kIsWeb || imageRef.startsWith('data:image')) {
      return;
    }

    try {
      final file = File(imageRef);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup
    }
  }
}

/// S3 / Cloudflare R2 storage stub ready for future cloud rollout.
class S3StorageService implements ImageStorageService {
  const S3StorageService({
    required this.bucket,
    required this.region,
    this.endpoint,
  });

  final String bucket;
  final String region;
  final String? endpoint;

  @override
  Future<String> saveProfileImage({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    // When credentials and pre-signed URL or S3 client are configured in .env,
    // upload bytes here and return public S3 URL.
    throw UnimplementedError('S3 storage provider requires AWS credentials in .env');
  }

  @override
  Future<void> deleteProfileImage({
    required String userId,
    required String imageRef,
  }) async {
    // S3 deleteObject implementation
  }
}

/// Resolves any profile photo string (data URI, local file path, or remote URL)
/// into an appropriate Flutter ImageProvider.
ImageProvider? resolveProfileImageProvider(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;

  if (photoUrl.startsWith('data:image')) {
    final commaIndex = photoUrl.indexOf(',');
    if (commaIndex != -1) {
      final base64Str = photoUrl.substring(commaIndex + 1);
      try {
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }
  }

  if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
    return NetworkImage(photoUrl);
  }

  if (!kIsWeb) {
    try {
      final file = File(photoUrl);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {
      // Fallback
    }
  }

  return null;
}
