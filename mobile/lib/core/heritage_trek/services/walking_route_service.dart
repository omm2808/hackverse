import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Walking Route Service — fetches real road/footpath waypoints using
/// the open OSRM walking profile API.
///
/// Converts OpenStreetMap walking paths into a list of [LatLng] coordinates
/// for rendering on the trek map. If offline or the service is unreachable,
/// it gracefully falls back to direct interpolation so the UI never breaks.
class WalkingRouteService {
  final HttpClient _httpClient;

  WalkingRouteService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient() {
    _httpClient.connectionTimeout = const Duration(seconds: 6);
  }

  /// Fetches real walking route waypoints from [origin] to [destination].
  ///
  /// Uses OSRM foot routing endpoint which respects pedestrian paths,
  /// sidewalks, and walkable streets.
  Future<List<LatLng>> fetchWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final request = await _httpClient.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'FitOdyssey/1.0 (com.fitodyssey.app)',
      );

      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;

        if (data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final firstRoute = (data['routes'] as List).first as Map<String, dynamic>;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List<dynamic>?;

          if (coords != null && coords.isNotEmpty) {
            final points = <LatLng>[];
            for (final coord in coords) {
              if (coord is List && coord.length >= 2) {
                final lon = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lon));
              }
            }
            if (points.isNotEmpty) {
              return points;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[WalkingRouteService] Routing fetch fallback ($e)');
    }

    // Graceful offline fallback: direct line from origin to destination
    return [origin, destination];
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}
