import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../../auth/models/user_profile.dart';

class StudentHousingLocation {
  final UserProfile profile;
  final double distanceKm;

  StudentHousingLocation({
    required this.profile,
    required this.distanceKm,
  });
}

class StudentsMapOverviewScreen extends StatefulWidget {
  const StudentsMapOverviewScreen({super.key});

  @override
  State<StudentsMapOverviewScreen> createState() => _StudentsMapOverviewScreenState();
}

class _StudentsMapOverviewScreenState extends State<StudentsMapOverviewScreen> {
  static const double _hospitalLat = 31.3543;
  static const double _hospitalLng = 27.2373;
  static const double _geofenceRadiusMeters = 200.0;

  bool _isLoading = true;
  String? _errorMessage;
  List<StudentHousingLocation> _allLocations = [];
  List<StudentHousingLocation> _filteredLocations = [];

  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, groupA, groupB, outside

  final MapController _mapController = MapController();
  UserProfile? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _fetchStudentsData();
  }

  Future<void> _fetchStudentsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
            _hospitalLat,
            _hospitalLng,
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

    if (_selectedFilter == 'groupA') {
      list = list.where((l) => l.profile.studentGroup == StudentGroup.groupA).toList();
    } else if (_selectedFilter == 'groupB') {
      list = list.where((l) => l.profile.studentGroup == StudentGroup.groupB).toList();
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

  void _recenterHospital() {
    setState(() => _selectedStudent = null);
    _mapController.move(
      const ll.LatLng(_hospitalLat, _hospitalLng),
      14.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final withGpsCount = _allLocations.where((l) => l.profile.latitude != null).length;
    final outsideCount = _allLocations.where((l) => !l.profile.isMatrouhResident).length;

    return Scaffold(
      backgroundColor: AppDesignTokens.surface(context),
      appBar: AppBar(
        title: const Text('خريطة توزيع مقار سكن الطلاب'),
        centerTitle: true,
        elevation: 0,
        actions: [
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
                              title: 'مغتربين',
                              value: '$outsideCount',
                              icon: Icons.hotel_rounded,
                              color: AppDesignTokens.warning,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      flex: 4,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: const MapOptions(
                              initialCenter: ll.LatLng(_hospitalLat, _hospitalLng),
                              initialZoom: 13.5,
                              minZoom: 6.0,
                              maxZoom: 18.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.matrouh.nurse_matrouh',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: const ll.LatLng(_hospitalLat, _hospitalLng),
                                    radius: _geofenceRadiusMeters,
                                    useRadiusInMeter: true,
                                    color: AppDesignTokens.primary.withOpacity(0.2),
                                    borderColor: AppDesignTokens.primary,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: const ll.LatLng(_hospitalLat, _hospitalLng),
                                    width: 48,
                                    height: 48,
                                    child: Tooltip(
                                      message: 'مستشفى مطروح العام 🏥 (نطاق الحضور)',
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.4),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                          border: Border.all(color: Colors.white, width: 2.5),
                                        ),
                                        child: const Icon(
                                          Icons.local_hospital_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
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
                                  onPressed: _recenterHospital,
                                  child: const Icon(Icons.local_hospital_rounded, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),

                          if (_selectedStudent != null)
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
                                _buildFilterChip('groupA', 'المجموعة A'),
                                const SizedBox(width: 6),
                                _buildFilterChip('groupB', 'المجموعة B'),
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
