import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationCheckResult {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class DeviceLocationService {
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  Future<LocationCheckResult> checkAndRequestPermission() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationCheckResult.serviceDisabled;
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationCheckResult.permissionDeniedForever;
    }

    if (permission == LocationPermission.denied) {
      return LocationCheckResult.permissionDenied;
    }

    return LocationCheckResult.granted;
  }

  Future<bool> ensurePermission() async {
    final res = await checkAndRequestPermission();
    return res == LocationCheckResult.granted;
  }

  Future<Position?> current({Duration timeout = const Duration(seconds: 7)}) async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      final perm = await checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
    } catch (e) {
      debugPrint('[DeviceLocationService] Failed to acquire current position: $e');
      // Fallback to last known position if current times out
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Stream<Position> stream({String busNumber = 'Bus'}) {
    LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Campus Bus • $busNumber',
          notificationText: '$busNumber is tracking live GPS. Tap to return.',
          enableWakeLock: true,
          notificationIcon: const AndroidResource(name: 'ic_launcher'),
        ),
      );
    } else if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 8,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 8,
      );
    }

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<bool> openSettings() async {
    return Geolocator.openAppSettings();
  }

  Future<bool> openLocationServiceSettings() async {
    return Geolocator.openLocationSettings();
  }
}
