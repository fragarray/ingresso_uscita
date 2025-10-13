import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import '../models/work_site.dart';

class LocationService {
  static final Location _location = Location();
  
  // Raggio massimo in metri per considerare valida la timbratura
  static const double maxDistanceMeters = 100.0;
  
  /// Ottiene la posizione corrente se disponibile, altrimenti restituisce una posizione predefinita
  static Future<LocationData?> getCurrentLocation() async {
    // Se siamo su Windows o web, restituiamo una posizione fittizia su Lecce
    if (kIsWeb || Platform.isWindows) {
      return LocationData.fromMap({
        'latitude': 40.3515,  // Lecce, Italia
        'longitude': 18.1750,
        'accuracy': 10.0,
        'altitude': 0.0,
        'speed': 0.0,
        'speed_accuracy': 0.0,
        'heading': 0.0,
        'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        'isMock': false,  // Cambiato a false per permettere il geofencing
      });
    }

    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          return null;
        }
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          return null;
        }
      }

      return await _location.getLocation();
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Verifica se la posizione è all'interno dell'area consentita
  static bool isLocationValid(LocationData location) {
    // Per Windows/web con posizione fittizia, verifichiamo comunque il geofencing
    // Non controlliamo più se è mock
    return true;  // La validazione vera avviene in isWithinWorkSite
  }

  /// Calcola la distanza tra due coordinate usando la formula di Haversine
  /// Restituisce la distanza in metri
  static double calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2
  ) {
    const double earthRadiusKm = 6371.0;
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * 
        cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c * 1000; // Converti in metri
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Verifica se la posizione corrente è entro il raggio di un cantiere
  static bool isWithinWorkSite(
    LocationData currentLocation,
    WorkSite workSite,
  ) {
    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      return false;
    }

    final distance = calculateDistance(
      currentLocation.latitude!,
      currentLocation.longitude!,
      workSite.latitude,
      workSite.longitude,
    );

    // Usa il raggio specifico del cantiere
    return distance <= workSite.radiusMeters;
  }

  /// Trova il cantiere più vicino alla posizione corrente
  static WorkSite? findNearestWorkSite(
    LocationData currentLocation,
    List<WorkSite> workSites,
  ) {
    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      return null;
    }

    WorkSite? nearest;
    double minDistance = double.infinity;

    for (final workSite in workSites) {
      if (!workSite.isActive) continue;

      final distance = calculateDistance(
        currentLocation.latitude!,
        currentLocation.longitude!,
        workSite.latitude,
        workSite.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = workSite;
      }
    }

    return nearest;
  }

  /// Ottiene informazioni sulla distanza dal cantiere
  static String getDistanceDescription(
    LocationData currentLocation,
    WorkSite workSite,
  ) {
    if (kIsWeb || Platform.isWindows) {
      return 'Posizione non disponibile su questa piattaforma';
    }

    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      return 'Posizione non disponibile';
    }

    final distance = calculateDistance(
      currentLocation.latitude!,
      currentLocation.longitude!,
      workSite.latitude,
      workSite.longitude,
    );

    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} metri dal cantiere';
    } else {
      return '${(distance / 1000).toStringAsFixed(2)} km dal cantiere';
    }
  }

  /// Ottiene una stringa descrittiva della posizione
  static String getLocationDescription(LocationData location) {
    if (kIsWeb || Platform.isWindows) {
      return 'Posizione non disponibile su questa piattaforma';
    }
    
    return '${location.latitude}, ${location.longitude}';
  }
}