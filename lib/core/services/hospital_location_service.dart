import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  RealtimeChannel? _subscription;

  HospitalLocationNotifier() : super(HospitalConfig.defaultMatrouhGeneral()) {
    loadConfig();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isInitialized) return;
    try {
      _subscription = SupabaseService.client
          .channel('public:app_settings:hospital_geofence')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_settings',
            callback: (payload) {
              loadConfig();
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) print('[HospitalLocationNotifier] realtime subscription note: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Instantly populate state from local cache so the UI has immediate data
      final savedStr = prefs.getString(_storageKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = jsonDecode(savedStr);
        if (decoded is Map<String, dynamic>) {
          state = HospitalConfig.fromJson(decoded);
          // Do NOT return here! Always fetch the latest configuration from Supabase.
        }
      }

      // 2. Fetch fresh dynamic configuration from Supabase app_settings
      if (SupabaseService.isInitialized) {
        final res = await SupabaseService.client
            .from('app_settings')
            .select('value')
            .eq('key', 'hospital_geofence')
            .maybeSingle();

        if (res != null && res['value'] != null) {
          final val = res['value'];
          final map = val is String ? jsonDecode(val) : Map<String, dynamic>.from(val);
          final loaded = HospitalConfig.fromJson(map);
          state = loaded;
          await prefs.setString(_storageKey, jsonEncode(loaded.toJson()));
          return;
        }

        // 3. Fallback: Check attendance_zones table if app_settings hasn't been set yet
        final zoneRes = await SupabaseService.client
            .from('attendance_zones')
            .select('*')
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (zoneRes != null) {
          final loaded = HospitalConfig(
            hospitalName: zoneRes['hospital_name']?.toString() ?? 'مستشفى مطروح العام',
            latitude: (zoneRes['latitude'] as num?)?.toDouble() ?? 31.3543,
            longitude: (zoneRes['longitude'] as num?)?.toDouble() ?? 27.2373,
            radiusMeters: (zoneRes['radius_meters'] as num?)?.toDouble() ?? 250.0,
            address: 'مرسى مطروح',
            updatedAt: DateTime.now(),
          );
          state = loaded;
          await prefs.setString(_storageKey, jsonEncode(loaded.toJson()));
        }
      }
    } catch (e) {
      if (kDebugMode) print('HospitalLocationNotifier load note: $e');
    }
  }

  String? lastError;

  Future<bool> updateConfig({
    required String hospitalName,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String? address,
  }) async {
    lastError = null;
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
    } catch (_) {}

    if (SupabaseService.isInitialized) {
      // 1. Try authoritative RPC first (bypasses RLS issues via SECURITY DEFINER)
      try {
        await SupabaseService.client.rpc(
          'update_hospital_geofence',
          params: {
            'p_hospital_name': updated.hospitalName,
            'p_latitude': updated.latitude,
            'p_longitude': updated.longitude,
            'p_radius_meters': updated.radiusMeters,
            'p_address': updated.address,
          },
        );
        return true;
      } catch (rpcErr) {
        if (kDebugMode) print('[HospitalLocationNotifier] RPC error, trying direct upsert: $rpcErr');

        // 2. Fallback to direct app_settings upsert
        try {
          await SupabaseService.client.from('app_settings').upsert({
            'key': 'hospital_geofence',
            'value': updated.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          // Non-blocking sync with attendance_zones
          try {
            await SupabaseService.client
                .from('attendance_zones')
                .update({
                  'hospital_name': updated.hospitalName,
                  'latitude': updated.latitude,
                  'longitude': updated.longitude,
                  'radius_meters': updated.radiusMeters,
                })
                .eq('is_active', true);
          } catch (_) {}

          return true;
        } catch (dbErr) {
          lastError = dbErr.toString();
          if (kDebugMode) print('HospitalLocationNotifier direct update error: $dbErr');
          return false;
        }
      }
    }
    return true;
  }
}

final hospitalConfigProvider =
    StateNotifierProvider<HospitalLocationNotifier, HospitalConfig>((ref) {
  return HospitalLocationNotifier();
});
