import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;

class LocationPermissionService {
  LocationPermissionService._() : _location = loc.Location();

  static final LocationPermissionService instance = LocationPermissionService._();

  final loc.Location _location;

  Future<bool> ensureReady(BuildContext context) async {
    if (!await _ensureServiceEnabled(context)) {
      return false;
    }
    return _ensurePermissionGranted(context);
  }

  Future<bool> _ensureServiceEnabled(BuildContext context) async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      return true;
    }

    serviceEnabled = await _location.serviceEnabled();
    if (serviceEnabled) {
      return true;
    }

    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Location Services'),
        content: const Text(
          'Location services must be turned on for attendance. '
          'Please enable GPS to continue.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (allow != true) {
      return false;
    }

    serviceEnabled = await _location.requestService();
    if (serviceEnabled) {
      return true;
    }

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn On Location'),
        content: const Text(
          'We still cannot access your location. Would you like to open '
          'device settings to enable Location Services?',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (openSettings == true) {
      await Geolocator.openLocationSettings();
      await Future.delayed(const Duration(milliseconds: 500));
      final enabledAfter =
          await Geolocator.isLocationServiceEnabled() || await _location.serviceEnabled();
      return enabledAfter;
    }

    return false;
  }

  Future<bool> _ensurePermissionGranted(BuildContext context) async {
    var permission = await Geolocator.checkPermission();

    if (_isGranted(permission)) {
      return true;
    }

    if (permission == LocationPermission.denied) {
      final allowRequest = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Allow Location Access'),
          content: const Text(
            'We use your live location to verify on-site attendance. '
            'Please allow location access.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (allowRequest == true) {
        permission = await Geolocator.requestPermission();
        if (_isGranted(permission)) {
          return true;
        }
      }
    }

    if (permission == LocationPermission.deniedForever) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Location access has been permanently denied. '
            'Please enable it from app settings to continue.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        await Geolocator.openAppSettings();
      }
    }

    return false;
  }

  bool _isGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}

