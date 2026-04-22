import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/observation.dart';

/// What happened when the OS share sheet closed.
enum ShareOutcome { success, dismissed, unavailable }

/// Builds a share payload (text + photo) and hands it to the OS share sheet.
class ShareService {
  ShareService({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  /// Share an observation through the native share sheet.
  Future<ShareOutcome> shareObservation(Observation obs) async {
    final text = _composeText(obs);

    // web: just share text + link
    if (kIsWeb) {
      final result = await Share.share(
        '$text\n\n${obs.photoUrl}',
        subject: 'UrbanFlora: ${obs.chosenSpecies.commonName}',
      );
      return _toOutcome(result);
    }

    final localPath = await _materialise(obs);
    if (localPath == null) {
      final result = await Share.share(text);
      return _toOutcome(result);
    }

    final result = await Share.shareXFiles(
      [XFile(localPath, mimeType: 'image/jpeg', name: 'urbanflora.jpg')],
      text: text,
      subject: 'UrbanFlora: ${obs.chosenSpecies.commonName}',
    );
    return _toOutcome(result);
  }

  ShareOutcome _toOutcome(ShareResult r) => switch (r.status) {
        ShareResultStatus.success => ShareOutcome.success,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => ShareOutcome.unavailable,
      };

  // download remote photo to a temp file so we can attach it
  Future<String?> _materialise(Observation obs) async {
    final url = obs.photoUrl;
    if (url.isEmpty) return null;

    if (!url.startsWith('http')) {
      final f = File(url);
      return f.existsSync() ? f.path : null;
    }

    final tmp = await Directory.systemTemp.createTemp('urbanflora_share');
    final out = File('${tmp.path}/share.jpg');
    await _dio.download(url, out.path);
    return out.path;
  }

  String _composeText(Observation obs) {
    final s = obs.chosenSpecies;
    final where = obs.address?.isNotEmpty == true ? ' in ${obs.address}' : '';
    return 'Found ${s.commonName} (${s.scientificName})$where with '
        'UrbanFlora — every plant is a chapter.';
  }
}

final shareServiceProvider = Provider<ShareService>((_) => ShareService());
