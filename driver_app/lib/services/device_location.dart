import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationCheckResult {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class DeviceLocationService {
  Future<LocationCheckResult> checkAndRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationCheckResult.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
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

  Future<Position?> current() async {
    if (!await ensurePermission()) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
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
