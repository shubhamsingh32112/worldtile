import 'package:flutter/material.dart';
import '../services/area_service.dart';
import '../theme/app_theme.dart';
import '../screens/map/area_details_page.dart';

/// Bottom sheet widget that displays areas for a selected state
class StateAreasBottomSheet extends StatefulWidget {
  final String stateKey;

  const StateAreasBottomSheet({
    super.key,
    required this.stateKey,
  });

  @override
  State<StateAreasBottomSheet> createState() => _StateAreasBottomSheetState();
}

class _StateAreasBottomSheetState extends State<StateAreasBottomSheet> {
  List<dynamic> _areas = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _stateName;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AreaService.getAreasForState(widget.stateKey);

      if (result['success'] == true) {
        setState(() {
          _areas = result['areas'] ?? [];
          _isLoading = false;
          // Extract state name from first area if available
          if (_areas.isNotEmpty) {
            // State name might be in the response, or we can derive it from stateKey
            _stateName = _getStateNameFromKey(widget.stateKey);
          }
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load areas';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading areas: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _getStateNameFromKey(String stateKey) {
    const Map<String, String> keyToName = {
      'karnataka': 'Karnataka',
      'maharashtra': 'Maharashtra',
      'delhi': 'Delhi NCR',
      'telangana': 'Telangana',
      'west_bengal': 'West Bengal',
      'rajasthan': 'Rajasthan',
      'kerala': 'Kerala',
    };
    return keyToName[stateKey.toLowerCase()] ?? stateKey;
  }

  void _navigateToAreaDetails(String areaKey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AreaDetailsPage(areaKey: areaKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stateName ?? widget.stateKey,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_areas.length} areas available',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.textSecondary),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadAreas,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _areas.isEmpty
                            ? Center(
                                child: Text(
                                  'No areas available',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _areas.length,
                                itemBuilder: (context, index) {
                                  final area = _areas[index];
                                  final areaKey = area['areaKey'] as String? ?? '';
                                  final areaName = area['areaName'] as String? ?? 'Unknown';
                                  final remainingSlots = area['remainingSlots'] as int? ?? 0;
                                  final totalSlots = area['totalSlots'] as int? ?? 0;
                                  final isDisabled = remainingSlots == 0;

                                  return ListTile(
                                    enabled: !isDisabled,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      areaName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: isDisabled
                                                ? AppTheme.textSecondary
                                                : AppTheme.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Slots: $remainingSlots / $totalSlots',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: isDisabled
                                                  ? AppTheme.textSecondary.withOpacity(0.6)
                                                  : remainingSlots < 10
                                                      ? Colors.orange
                                                      : AppTheme.textSecondary,
                                            ),
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right,
                                      color: isDisabled
                                          ? AppTheme.textSecondary.withOpacity(0.3)
                                          : AppTheme.textSecondary,
                                    ),
                                    onTap: isDisabled
                                        ? null
                                        : () {
                                            _navigateToAreaDetails(areaKey);
                                          },
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

