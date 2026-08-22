import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class HospitalConfig {
  final String hospitalName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String address;
  final DateTime updatedAt;

  const HospitalConfig({
    this.hospitalName = 'مستشفى مطروح العام',
    this.latitude = 31.3543,
    this.longitude = 27.2373,
    this.radiusMeters = 250.0,
    this.address = 'شارع الجلاء، مرسى مطروح',
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'hospital_name': hospitalName,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'address': address,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory HospitalConfig.fromJson(Map<String, dynamic> json) {
    return HospitalConfig(
      hospitalName: json['hospital_name']?.toString() ?? 'مستشفى مطروح العام',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 31.3543,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 27.2373,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 250.0,
      address: json['address']?.toString() ?? 'شارع الجلاء، مرسى مطروح',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static HospitalConfig defaultMatrouhGeneral() => HospitalConfig(updatedAt: DateTime.now());

  HospitalConfig copyWith({
    String? hospitalName,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? address,
    DateTime? updatedAt,
  }) {
    return HospitalConfig(
      hospitalName: hospitalName ?? this.hospitalName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class HospitalLocationNotifier extends StateNotifier<HospitalConfig> {
  static const String _storageKey = 'hospital_geofence_config_v2';

  HospitalLocationNotifier() : super(HospitalConfig.defaultMatrouhGeneral()) {
    loadConfig();
  }

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_storageKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = jsonDecode(savedStr);
        if (decoded is Map<String, dynamic>) {
          state = HospitalConfig.fromJson(decoded);
          return;
        }
      }

      // Try fetching from Supabase app_settings or profiles metadata if available
      if (SupabaseService.isInitialized) {
        final res = await SupabaseService.client
            .from('system_settings')
            .select('setting_value')
            .eq('setting_key', 'hospital_geofence')
            .maybeSingle();

        if (res != null && res['setting_value'] != null) {
          final val = res['setting_value'];
          final map = val is String ? jsonDecode(val) : Map<String, dynamic>.from(val);
          final loaded = HospitalConfig.fromJson(map);
          state = loaded;
          await prefs.setString(_storageKey, jsonEncode(loaded.toJson()));
        }
      }
    } catch (e) {
      if (kDebugMode) print('HospitalLocationNotifier load note: $e');
    }
  }

  Future<bool> updateConfig({
    required String hospitalName,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String? address,
  }) async {
    final updated = HospitalConfig(
      hospitalName: hospitalName.trim(),
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      address: address?.trim() ?? state.address,
      updatedAt: DateTime.now(),
    );

    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(updated.toJson()));

      // Try updating Supabase system_settings in background
      if (SupabaseService.isInitialized) {
        try {
          await SupabaseService.client.from('system_settings').upsert({
            'setting_key': 'hospital_geofence',
            'setting_value': updated.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('HospitalLocationNotifier update error: $e');
      return false;
    }
  }
}

final hospitalConfigProvider =
    StateNotifierProvider<HospitalLocationNotifier, HospitalConfig>((ref) {
  return HospitalLocationNotifier();
});
