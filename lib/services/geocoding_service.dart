import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Servizio di geocoding cross-platform usando Nominatim API di OpenStreetMap
/// Funziona su Android, iOS, Windows, macOS, Linux e Web
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'SinergyWork/1.0';
  
  /// Cerca un indirizzo e restituisce le coordinate
  /// 
  /// [address] - L'indirizzo da cercare (es. "Via Roma 10, Milano")
  /// 
  /// Ritorna una lista di risultati con coordinate e dettagli
  static Future<List<GeocodingResult>> searchAddress(String address) async {
    if (address.trim().isEmpty) {
      return [];
    }
    
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        '$_baseUrl/search?q=$encodedAddress&format=json&limit=5&addressdetails=1'
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'it,en',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        return data.map((item) {
          return GeocodingResult(
            displayName: item['display_name'] ?? '',
            latitude: double.parse(item['lat'] ?? '0'),
            longitude: double.parse(item['lon'] ?? '0'),
            type: item['type'] ?? '',
            importance: (item['importance'] ?? 0.0).toDouble(),
            address: _parseAddress(item['address']),
          );
        }).toList();
      } else {
        throw Exception('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      print('Errore geocoding: $e');
      rethrow;
    }
  }
  
  /// Ottiene l'indirizzo da coordinate (reverse geocoding)
  /// 
  /// [position] - Le coordinate da cui ottenere l'indirizzo
  static Future<GeocodingResult?> reverseGeocode(LatLng position) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&addressdetails=1'
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'it,en',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        return GeocodingResult(
          displayName: data['display_name'] ?? '',
          latitude: double.parse(data['lat'] ?? '0'),
          longitude: double.parse(data['lon'] ?? '0'),
          type: data['type'] ?? '',
          importance: (data['importance'] ?? 0.0).toDouble(),
          address: _parseAddress(data['address']),
        );
      }
      return null;
    } catch (e) {
      print('Errore reverse geocoding: $e');
      return null;
    }
  }
  
  static AddressDetails _parseAddress(dynamic addressData) {
    if (addressData == null) {
      return AddressDetails();
    }
    
    return AddressDetails(
      road: addressData['road'],
      houseNumber: addressData['house_number'],
      city: addressData['city'] ?? addressData['town'] ?? addressData['village'],
      municipality: addressData['municipality'],
      province: addressData['province'] ?? addressData['state'],
      postcode: addressData['postcode'],
      country: addressData['country'],
      countryCode: addressData['country_code'],
    );
  }
}

/// Risultato di una ricerca geocoding
class GeocodingResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;
  final double importance;
  final AddressDetails address;
  
  GeocodingResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type = '',
    this.importance = 0.0,
    AddressDetails? address,
  }) : address = address ?? AddressDetails();
  
  LatLng get position => LatLng(latitude, longitude);
  
  /// Descrizione breve dell'indirizzo
  String get shortDescription {
    final parts = <String>[];
    if (address.road != null) parts.add(address.road!);
    if (address.city != null) parts.add(address.city!);
    return parts.isNotEmpty ? parts.join(', ') : displayName;
  }
  
  @override
  String toString() => displayName;
}

/// Dettagli dell'indirizzo
class AddressDetails {
  final String? road;
  final String? houseNumber;
  final String? city;
  final String? municipality;
  final String? province;
  final String? postcode;
  final String? country;
  final String? countryCode;
  
  AddressDetails({
    this.road,
    this.houseNumber,
    this.city,
    this.municipality,
    this.province,
    this.postcode,
    this.country,
    this.countryCode,
  });
  
  String get fullStreet {
    if (road != null && houseNumber != null) {
      return '$road $houseNumber';
    }
    return road ?? '';
  }
  
  String get cityWithPostcode {
    final parts = <String>[];
    if (postcode != null) parts.add(postcode!);
    if (city != null) parts.add(city!);
    return parts.join(' ');
  }
}
