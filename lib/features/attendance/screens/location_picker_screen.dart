import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String hospitalName;

  LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.hospitalName,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialRadius;
  final String initialHospitalName;

  const LocationPickerScreen({
    super.key,
    this.initialLat = 31.3543,
    this.initialLng = 27.2373,
    this.initialRadius = 150.0,
    this.initialHospitalName = 'مستشفى مطروح العام',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  late double _selectedRadius;
  late TextEditingController _nameController;
  bool _isLoadingLocation = false;
  bool _mapReady = false;

  // Radius bounds
  static const double _minRadius = 50.0;
  static const double _maxRadius = 500.0;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLat, widget.initialLng);
    _selectedRadius = widget.initialRadius.clamp(_minRadius, _maxRadius);
    _nameController =
        TextEditingController(text: widget.initialHospitalName);
    // Timeout to prevent infinite gray screen loading overlay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_mapReady) {
        setState(() => _mapReady = true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location helpers ──────────────────────────────────────────────────────

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showSnack('خدمة GPS غير مفعّلة');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        final newLatLng = LatLng(pos.latitude, pos.longitude);
        setState(() => _selectedLocation = newLatLng);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLatLng, 17),
        );
      } else {
        _showSnack('صلاحية الموقع مرفوضة');
      }
    } catch (_) {
      _showSnack('تعذر تحديد موقعك الحالي');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _onMapTap(LatLng tapped) {
    setState(() => _selectedLocation = tapped);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.deepNavy,
        foregroundColor: Colors.white,
        title: const Text(
          'تحديد موقع منطقة الحضور',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 16.5,
            ),
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              setState(() => _mapReady = true);
            },
            onTap: _onMapTap,
            markers: {
              Marker(
                markerId: const MarkerId('zone_center'),
                position: _selectedLocation,
                draggable: true,
                onDragEnd: (pos) => setState(() => _selectedLocation = pos),
                infoWindow: InfoWindow(
                  title: _nameController.text.isEmpty
                      ? 'منطقة الحضور'
                      : _nameController.text,
                  snippet:
                      'نطاق: ${_selectedRadius.toStringAsFixed(0)} متر',
                ),
              ),
            },
            circles: {
              Circle(
                circleId: const CircleId('geofence_circle'),
                center: _selectedLocation,
                radius: _selectedRadius,
                fillColor: AppColors.primaryTeal.withValues(alpha: 0.18),
                strokeColor: AppColors.primaryTeal,
                strokeWidth: 2,
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),

          // ── Loading overlay ─────────────────────────────────────────────
          if (!_mapReady)
            Container(
              color: AppColors.deepNavy,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // ── GPS FAB ─────────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 280,
            child: FloatingActionButton(
              heroTag: 'fab_gps',
              mini: true,
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _isLoadingLocation ? null : _goToCurrentLocation,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryTeal,
                      ),
                    )
                  : const Icon(Icons.my_location,
                      color: AppColors.primaryTeal, size: 22),
            ).animate().scale(duration: 300.ms, curve: Curves.easeOut),
          ),

          // ── Zoom controls ────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 360,
            child: Column(
              children: [
                _ZoomBtn(
                  icon: Icons.add,
                  onTap: () => _mapController
                      ?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 4),
                _ZoomBtn(
                  icon: Icons.remove,
                  onTap: () => _mapController
                      ?.animateCamera(CameraUpdate.zoomOut()),
                ),
              ],
            ),
          ),

          // ── Bottom Sheet Panel ───────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Zone name field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'اسم المستشفى / المنطقة',
              prefixIcon: const Icon(Icons.local_hospital_outlined,
                  color: AppColors.primaryTeal),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryTeal, width: 2),
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Coordinates display
          Row(
            children: [
              const Icon(Icons.location_pin,
                  size: 16, color: AppColors.primaryTeal),
              const SizedBox(width: 6),
              Text(
                'خط العرض: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.location_pin,
                  size: 16, color: AppColors.primaryTeal),
              const SizedBox(width: 6),
              Text(
                'خط الطول: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Radius slider
          Row(
            children: [
              const Text(
                'نطاق الحضور:',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedRadius.toStringAsFixed(0)} متر',
                  style: const TextStyle(
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryTeal,
              inactiveTrackColor: AppColors.primaryTeal.withValues(alpha: 0.2),
              thumbColor: AppColors.primaryTeal,
              overlayColor: AppColors.primaryTeal.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _selectedRadius,
              min: _minRadius,
              max: _maxRadius,
              divisions: 90, // steps of ~5m
              onChanged: (val) {
                setState(() => _selectedRadius = val.roundToDouble());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_minRadius.toStringAsFixed(0)}م',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              Text('${_maxRadius.toStringAsFixed(0)}م',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),

          const SizedBox(height: 16),

          // Quick current location button
          OutlinedButton.icon(
            onPressed: _isLoadingLocation ? null : _goToCurrentLocation,
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('استخدام موقعي الحالي'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryTeal,
              side: const BorderSide(color: AppColors.primaryTeal),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 10),

          // Save button
          CustomButton(
            text:
                'حفظ منطقة الحضور (${_selectedRadius.toStringAsFixed(0)}م)',
            icon: Icons.check_circle_outline,
            onPressed: () {
              Navigator.pop(
                context,
                LocationPickerResult(
                  latitude: _selectedLocation.latitude,
                  longitude: _selectedLocation.longitude,
                  radiusMeters: _selectedRadius,
                  hospitalName: _nameController.text.trim().isEmpty
                      ? 'مستشفى مطروح العام'
                      : _nameController.text.trim(),
                ),
              );
            },
          ),
        ],
      ),
    ).animate().slideY(
          begin: 0.3,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ── Zoom button ───────────────────────────────────────────────────────────────

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.deepNavy),
      ),
    );
  }
}
