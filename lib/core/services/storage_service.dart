import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of uploading a photo. Same URL is reused as the thumbnail.
class UploadedPhoto {
  const UploadedPhoto({required this.photoUrl, required this.thumbUrl});
  final String photoUrl;
  final String thumbUrl;
}

/// Uploads observation photos to Firebase Storage.
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Upload a photo file and return its download URL.
  Future<UploadedPhoto> uploadObservationPhoto({
    required String uid,
    required String observationId,
    required String localPath,
  }) async {
    // web uses blob urls already, no upload needed
    if (kIsWeb) {
      return UploadedPhoto(photoUrl: localPath, thumbUrl: localPath);
    }

    final file = File(localPath);
    final ref = _storage
        .ref()
        .child('users')
        .child(uid)
        .child('observations')
        .child('$observationId.jpg');

    final snap = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await snap.ref.getDownloadURL();
    return UploadedPhoto(photoUrl: url, thumbUrl: url);
  }
}

final storageServiceProvider =
    Provider<StorageService>((_) => StorageService());
