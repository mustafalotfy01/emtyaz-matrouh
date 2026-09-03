import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/hospital_location_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';

class StudentHousingLocation {
  final UserProfile profile;
  final double distanceKm;

  StudentHousingLocation({
    required this.profile,
    required this.distanceKm,
  });
}

class StudentsMapOverviewScreen extends ConsumerStatefulWidget {
  const StudentsMapOverviewScreen({super.key});

  @override
  ConsumerState<StudentsMapOverviewScreen> createState() => _StudentsMapOverviewScreenState();
}

class _StudentsMapOverviewScreenState extends ConsumerState<StudentsMapOverviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StudentHousingLocation> _allLocations = [];
  List<StudentHousingLocation> _filteredLocations = [];

  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, groupA, groupB, outside

  final MapController _mapController = MapController();
  UserProfile? _selectedStudent;

  // Admin edit hospital mode state
  bool _isEditingHospital = false;
  ll.LatLng? _draftHospitalPoint;
  double _draftRadius = 250.0;
  final _hospitalNameCtrl = TextEditingController();
  final _hospitalAddressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudentsData();
  }

  @override
  void dispose() {
    _hospitalNameCtrl.dispose();
    _hospitalAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final hospitalConfig = ref.read(hospitalConfigProvider);

    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('*')
          .eq('role', 'student')
          .order('full_name', ascending: true);

      final List<StudentHousingLocation> locations = [];

      for (var row in (res as List)) {
        final profile = UserProfile.fromJson(Map<String, dynamic>.from(row));

        double distanceKm = 0.0;
        if (profile.latitude != null && profile.longitude != null) {
          final meters = Geolocator.distanceBetween(
            hospitalConfig.latitude,
            hospitalConfig.longitude,
            profile.latitude!,
            profile.longitude!,
          );
          distanceKm = (meters / 1000.0);
        }

        locations.add(StudentHousingLocation(
          profile: profile,
          distanceKm: distanceKm,
        ));
      }

      setState(() {
        _allLocations = locations;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل بيانات مواقع الطلاب: $e';
      });
    }
  }

  void _applyFilter() {
    List<StudentHousingLocation> list = List.from(_allLocations);

    if (_searchQuery.isNotEmpty) {
      list = list.where((loc) {
        final q = _searchQuery.toLowerCase();
        return loc.profile.fullName.toLowerCase().contains(q) ||
            loc.profile.universityCode.toLowerCase().contains(q) ||
            loc.profile.residenceAddress.toLowerCase().contains(q);
      }).toList();
    }

    if (_selectedFilter == 'unassigned') {
      list = list.where((l) => l.profile.studentGroupId == null).toList();
    } else if (_selectedFilter == 'practical') {
      list = list.where((l) => l.profile.classification == StudentClassification.practicalStrong).toList();
    } else if (_selectedFilter == 'theoretical') {
      list = list.where((l) => l.profile.classification == StudentClassification.theoreticalStrong).toList();
    } else if (_selectedFilter == 'weak') {
      list = list.where((l) => l.profile.classification == StudentClassification.weak).toList();
    } else if (_selectedFilter == 'outside') {
      list = list.where((l) => !l.profile.isMatrouhResident).toList();
    }

    setState(() {
      _filteredLocations = list;
    });
  }

  void _focusOnStudent(StudentHousingLocation loc) {
    setState(() => _selectedStudent = loc.profile);
    if (loc.profile.latitude != null && loc.profile.longitude != null) {
      _mapController.move(
        ll.LatLng(loc.profile.latitude!, loc.profile.longitude!),
        15.5,
      );
    }
  }

  void _recenterHospital(HospitalConfig config) {
    setState(() => _selectedStudent = null);
    final target = _isEditingHospital && _draftHospitalPoint != null
        ? _draftHospitalPoint!
        : ll.LatLng(config.latitude, config.longitude);
    _mapController.move(target, 14.5);
  }

  void _startEditingHospital(HospitalConfig config) {
    setState(() {
      _isEditingHospital = true;
      _selectedStudent = null;
      _draftHospitalPoint = ll.LatLng(config.latitude, config.longitude);
      _draftRadius = config.radiusMeters;
      _hospitalNameCtrl.text = config.hospitalName;
      _hospitalAddressCtrl.text = config.address;
    });
    _mapController.move(_draftHospitalPoint!, 15.0);
  }

  Future<void> _useCurrentGpsForHospital() async {
    final loc = await LocationService.getCurrentLocation();
    if (loc.latitude != null && loc.longitude != null) {
      final point = ll.LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        _draftHospitalPoint = point;
      });
      _mapController.move(point, 16.0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم جلب إحداثياتك الحالية بدقة وتحديدها للمستشفى 📍'),
            backgroundColor: AppDesignTokens.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديد موقع GPS الحالي. يرجى تفعيل الموقع والتأكد من الصلاحيات.'),
            backgroundColor: AppDesignTokens.danger,
          ),
        );
      }
    }
  }

  Future<void> _saveHospitalConfig() async {
    if (_draftHospitalPoint == null) return;

    final success = await ref.read(hospitalConfigProvider.notifier).updateConfig(
          hospitalName: _hospitalNameCtrl.text.trim().isNotEmpty
              ? _hospitalNameCtrl.text.trim()
              : 'مستشفى مطروح العام',
          latitude: _draftHospitalPoint!.latitude,
          longitude: _draftHospitalPoint!.longitude,
          radiusMeters: _draftRadius,
          address: _hospitalAddressCtrl.text.trim(),
        );

    if (mounted) {
      if (success) {
        setState(() {
          _isEditingHospital = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تثبيت وتحديث موقع المستشفى بنطاق أمان (${_draftRadius.round()} متر) بنجاح ✅',
            ),
            backgroundColor: AppDesignTokens.success,
          ),
        );
        _fetchStudentsData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل حفظ الإعدادات، يرجى المحاولة ثانية.'),
            backgroundColor: AppDesignTokens.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitalConfig = ref.watch(hospitalConfigProvider);
    final user = ref.watch(authProvider).user;
    final canManageHospital = user?.role == UserRole.superAdmin || user?.role == UserRole.leader;

    final withGpsCount = _allLocations.where((l) => l.profile.latitude != null).length;
    final outsideCount = _allLocations.where((l) => !l.profile.isMatrouhResident).length;

    final activeHospitalLat = _isEditingHospital && _draftHospitalPoint != null
        ? _draftHospitalPoint!.latitude
        : hospitalConfig.latitude;
    final activeHospitalLng = _isEditingHospital && _draftHospitalPoint != null
        ? _draftHospitalPoint!.longitude
        : hospitalConfig.longitude;
    final activeRadius = _isEditingHospital ? _draftRadius : hospitalConfig.radiusMeters;

    return Scaffold(
      backgroundColor: AppDesignTokens.surface(context),
      appBar: AppBar(
        title: Text(_isEditingHospital ? 'تحديد موقع المستشفى ونطاق البصمة' : 'خريطة توزيع مقار سكن الطلاب'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (canManageHospital && !_isEditingHospital)
            TextButton.icon(
              onPressed: () => _startEditingHospital(hospitalConfig),
              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
              label: const Text('تعديل المستشفى والزون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          if (!_isEditingHospital)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث البيانات',
              onPressed: _fetchStudentsData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppDesignTokens.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchStudentsData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppDesignTokens.surface(context),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: 'إجمالي الطلاب',
                              value: '${_allLocations.length}',
                              icon: Icons.people_alt_rounded,
                              color: AppDesignTokens.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: 'مسجل إحداثياتهم',
                              value: '$withGpsCount',
                              icon: Icons.pin_drop_rounded,
                              color: AppDesignTokens.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: 'نطاق المستشفى',
                              value: '${activeRadius.round()}م',
                              icon: Icons.local_hospital_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      flex: _isEditingHospital ? 6 : 4,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: ll.LatLng(activeHospitalLat, activeHospitalLng),
                              initialZoom: 14.0,
                              minZoom: 6.0,
                              maxZoom: 18.5,
                              onTap: (tapPosition, point) {
                                if (_isEditingHospital) {
                                  setState(() {
                                    _draftHospitalPoint = point;
                                  });
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.matrouh.nurse_matrouh',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: ll.LatLng(activeHospitalLat, activeHospitalLng),
                                    radius: activeRadius,
                                    useRadiusInMeter: true,
                                    color: (_isEditingHospital ? Colors.redAccent : AppDesignTokens.primary)
                                        .withOpacity(0.25),
                                    borderColor: _isEditingHospital ? Colors.redAccent : AppDesignTokens.primary,
                                    borderStrokeWidth: 2.5,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: ll.LatLng(activeHospitalLat, activeHospitalLng),
                                    width: _isEditingHospital ? 56 : 48,
                                    height: _isEditingHospital ? 56 : 48,
                                    child: Tooltip(
                                      message: '${hospitalConfig.hospitalName} 🏥 (نطاق الحضور: ${activeRadius.round()}م)',
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.5),
                                              blurRadius: _isEditingHospital ? 12 : 8,
                                              spreadRadius: _isEditingHospital ? 3 : 2,
                                            ),
                                          ],
                                          border: Border.all(
                                            color: _isEditingHospital ? Colors.amberAccent : Colors.white,
                                            width: _isEditingHospital ? 3.5 : 2.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.local_hospital_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!_isEditingHospital)
                                    ..._filteredLocations
                                        .where((l) => l.profile.latitude != null && l.profile.longitude != null)
                                        .map((item) {
                                      final isA = item.profile.studentGroup == StudentGroup.groupA;
                                      final color = isA ? AppDesignTokens.primary : Colors.orange;
                                      final isSelected = _selectedStudent?.id == item.profile.id;

                                      return Marker(
                                        point: ll.LatLng(item.profile.latitude!, item.profile.longitude!),
                                        width: isSelected ? 48 : 38,
                                        height: isSelected ? 48 : 38,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() => _selectedStudent = item.profile);
                                            _mapController.move(
                                              ll.LatLng(item.profile.latitude!, item.profile.longitude!),
                                              15.5,
                                            );
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? Colors.amberAccent : Colors.white,
                                                width: isSelected ? 3 : 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isSelected ? Colors.amberAccent : color).withOpacity(0.5),
                                                  blurRadius: isSelected ? 8 : 4,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                item.profile.fullName.isNotEmpty
                                                    ? item.profile.fullName.trim().split(' ').first[0]
                                                    : 'ط',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ],
                          ),

                          if (_isEditingHospital)
                            Positioned(
                              top: 12,
                              left: 60,
                              right: 60,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade900.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'اضغط على الخريطة لتحديد مكان المستشفى العام',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          Positioned(
                            top: 12,
                            left: 12,
                            child: Column(
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'map_zoom_in',
                                  backgroundColor: AppDesignTokens.surface(context),
                                  onPressed: () {
                                    final zoom = _mapController.camera.zoom + 1.0;
                                    _mapController.move(_mapController.camera.center, zoom);
                                  },
                                  child: const Icon(Icons.add, color: AppDesignTokens.primary),
                                ),
                                const SizedBox(height: 6),
                                FloatingActionButton.small(
                                  heroTag: 'map_zoom_out',
                                  backgroundColor: AppDesignTokens.surface(context),
                                  onPressed: () {
                                    final zoom = _mapController.camera.zoom - 1.0;
                                    _mapController.move(_mapController.camera.center, zoom);
                                  },
                                  child: const Icon(Icons.remove, color: AppDesignTokens.primary),
                                ),
                                const SizedBox(height: 6),
                                FloatingActionButton.small(
                                  heroTag: 'map_recenter',
                                  backgroundColor: AppDesignTokens.surface(context),
                                  tooltip: 'العودة لمستشفى مطروح العام',
                                  onPressed: () => _recenterHospital(hospitalConfig),
                                  child: const Icon(Icons.local_hospital_rounded, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),

                          if (_selectedStudent != null && !_isEditingHospital)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: AppCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    AppAvatar(
                                      name: _selectedStudent!.fullName,
                                      imageUrl: _selectedStudent!.avatarUrl,
                                      size: AppAvatarSize.medium,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _selectedStudent!.fullName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'العنوان: ${_selectedStudent!.residenceAddress.isEmpty ? "غير مسجل" : _selectedStudent!.residenceAddress}',
                                            style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_selectedStudent!.phoneNumber.isNotEmpty)
                                            Text(
                                              'الهاتف: ${_selectedStudent!.phoneNumber}',
                                              style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textMuted(context)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () => setState(() => _selectedStudent = null),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_isEditingHospital)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.surface(context),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.fmd_good_rounded, color: Colors.redAccent, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        'إحداثيات المستشفى: (${activeHospitalLat.toStringAsFixed(4)}, ${activeHospitalLng.toStringAsFixed(4)})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _useCurrentGpsForHospital,
                                    icon: const Icon(Icons.my_location_rounded, size: 16),
                                    label: const Text('موقعي الحالي (GPS)', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'نطاق البصمة المسموح به: ${_draftRadius.round()} متر',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: AppDesignTokens.textPrimary(context),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _draftRadius <= 150 ? 'نطاق ضيق (مبنى الطوارئ)' : (_draftRadius <= 350 ? 'نطاق متوسط (المجمع الطبي)' : 'نطاق واسع'),
                                    style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _draftRadius.clamp(50.0, 1500.0),
                                min: 50.0,
                                max: 1500.0,
                                divisions: 29,
                                activeColor: AppDesignTokens.primary,
                                label: '${_draftRadius.round()} م',
                                onChanged: (val) => setState(() => _draftRadius = val),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      text: 'إلغاء',
                                      variant: AppButtonVariant.ghost,
                                      onPressed: () => setState(() => _isEditingHospital = false),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: AppButton(
                                      text: 'حفظ وتثبيت موقع المستشفى والزون ✅',
                                      variant: AppButtonVariant.primary,
                                      icon: Icons.check_circle_rounded,
                                      onPressed: _saveHospitalConfig,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (!_isEditingHospital) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Column(
                          children: [
                            AppInput(
                              hint: 'بحث باسم الطالب، الكود الجامعي، أو المنطقة...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              onChanged: (val) {
                                _searchQuery = val.trim();
                                _applyFilter();
                              },
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('all', 'الكل (${_allLocations.length})'),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('unassigned', 'بدون جروب'),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('practical', '🩺 شاطر عملي'),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('theoretical', '📚 دحيح نظري'),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('weak', '⚠️ ضعيف'),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('outside', 'المغتربين ($outsideCount)'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        flex: 3,
                        child: _filteredLocations.isEmpty
                            ? Center(
                                child: Text(
                                  'لا توجد نتائج مطابقة',
                                  style: TextStyle(color: AppDesignTokens.textSecondary(context)),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _filteredLocations.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final item = _filteredLocations[index];
                                  final hasCoords = item.profile.latitude != null;

                                  return AppCard(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: AppAvatar(
                                        name: item.profile.fullName,
                                        imageUrl: item.profile.avatarUrl,
                                        size: AppAvatarSize.small,
                                      ),
                                      title: Text(
                                        item.profile.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        item.profile.residenceAddress.isNotEmpty
                                            ? item.profile.residenceAddress
                                            : (item.profile.isMatrouhResident ? 'مطروح' : 'خارج المحافظة'),
                                        style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (hasCoords)
                                            AppBadge(
                                              label: '${item.distanceKm.toStringAsFixed(1)} كم',
                                              variant: item.distanceKm <= 5.0
                                                  ? AppBadgeVariant.success
                                                  : AppBadgeVariant.warning,
                                              size: AppBadgeSize.small,
                                            )
                                          else
                                            const AppBadge(
                                              label: 'بدون GPS',
                                              variant: AppBadgeVariant.neutral,
                                              size: AppBadgeSize.small,
                                            ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: Icon(
                                              hasCoords ? Icons.my_location_rounded : Icons.location_off_rounded,
                                              size: 18,
                                              color: hasCoords ? AppDesignTokens.primary : Colors.grey,
                                            ),
                                            onPressed: hasCoords ? () => _focusOnStudent(item) : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: AppDesignTokens.primary,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = key);
          _applyFilter();
        }
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: AppDesignTokens.textSecondary(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
