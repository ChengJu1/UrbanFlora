import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_keys.dart';
import '../constants/app_constants.dart';
import '../models/species.dart';

/// Thrown when something goes wrong calling the Pl@ntNet API.
class PlantNetException implements Exception {
  PlantNetException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  /// A short message we can show to the user.
  String get friendly {
    switch (statusCode) {
      case 401:
      case 403:
        return 'The plant identification key was rejected.';
      case 404:
        return 'The identification service is unreachable right now.';
      case 413:
        return 'That photo is a bit too large. Try a smaller one.';
      case 429:
        return 'Too many tries in a short time. Wait a moment and try again.';
      case null:
        return 'Network problem. Check your connection and try again.';
      default:
        return 'Could not reach the identification service. Try again in a moment.';
    }
  }

  @override
  String toString() => friendly;
}

/// Calls Pl@ntNet to turn a photo into top-k plant guesses.
class PlantNetService {
  PlantNetService({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  /// Identify a plant from a local photo.
  Future<List<SpeciesCandidate>> identify({
    required String imagePath,
    String organ = 'auto',
    int topK = 3,
  }) async {
    // fall back to demo data so the app still runs without a key
    if (ApiKeys.plantNet == 'YOUR_PLANTNET_API_KEY') {
      return _demoCandidates();
    }

    final form = FormData.fromMap({
      'organs': organ,
      'images': await MultipartFile.fromFile(imagePath, filename: 'plant.jpg'),
    });

    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        AppConstants.plantNetEndpoint,
        queryParameters: {'api-key': ApiKeys.plantNet},
        data: form,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final results = (resp.data?['results'] as List?) ?? const [];
      return results
          .cast<Map<String, dynamic>>()
          .take(topK)
          .map(SpeciesCandidate.fromPlantNet)
          .toList();
    } on DioException catch (e) {
      throw PlantNetException(
        e.message ?? 'Pl@ntNet request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  List<SpeciesCandidate> _demoCandidates() {
    return const [
      SpeciesCandidate(
        scientificName: 'Bellis perennis',
        commonName: 'Common daisy',
        family: 'Asteraceae',
        genus: 'Bellis',
        score: 0.82,
      ),
      SpeciesCandidate(
        scientificName: 'Taraxacum officinale',
        commonName: 'Dandelion',
        family: 'Asteraceae',
        genus: 'Taraxacum',
        score: 0.41,
      ),
      SpeciesCandidate(
        scientificName: 'Trifolium repens',
        commonName: 'White clover',
        family: 'Fabaceae',
        genus: 'Trifolium',
        score: 0.12,
      ),
    ];
  }
}

final plantNetServiceProvider =
    Provider<PlantNetService>((_) => PlantNetService());
