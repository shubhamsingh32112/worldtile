import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/geocoding_service.dart';

/// A search bar widget for searching places on the map
/// Displays search results in a dropdown and handles place selection
class MapSearchBar extends StatefulWidget {
  /// Callback when a place is selected
  /// Parameters: latitude, longitude
  final Function(double lat, double lng) onPlaceSelected;

  /// Optional placeholder text
  final String? hintText;

  const MapSearchBar({
    super.key,
    required this.onPlaceSelected,
    this.hintText,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PlaceResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  String? _errorMessage;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _focusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _showResults = _focusNode.hasFocus && _searchResults.isNotEmpty;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    final hasText = _searchController.text.isNotEmpty;
    
    setState(() {
      _hasText = hasText;
    });
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    // Debounce search to avoid too many API calls
    _debounceSearch(query);
  }

  Timer? _debounceTimer;

  void _debounceSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    final result = await GeocodingService.searchPlaces(query, limit: 5);

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      if (result['success'] == true) {
        _searchResults = result['places'] as List<PlaceResult>;
        _showResults = _focusNode.hasFocus && _searchResults.isNotEmpty;
        _errorMessage = null;
      } else {
        _searchResults = [];
        _showResults = false;
        _errorMessage = result['message'] as String? ?? 'Search failed';
      }
    });
  }

  void _selectPlace(PlaceResult place) {
    _searchController.text = place.name;
    setState(() {
      _showResults = false;
      _searchResults = [];
    });
    _focusNode.unfocus();
    widget.onPlaceSelected(place.latitude, place.longitude);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showResults = false;
      _errorMessage = null;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: widget.hintText ?? 'Search for a place (e.g., rt nagar)',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.textSecondary,
              ),
              suffixIcon: _hasText
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onSubmitted: (value) {
              if (_searchResults.isNotEmpty) {
                _selectPlace(_searchResults.first);
              }
            },
          ),
        ),
        // Search results dropdown
        if (_showResults && _searchResults.isNotEmpty)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: AppTheme.backgroundColor,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color: AppTheme.primaryColor,
                          ),
                          title: Text(
                            place.name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          subtitle: place.context != null
                              ? Text(
                                  place.context!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              : Text(
                                  place.placeName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => _selectPlace(place),
                          hoverColor: AppTheme.backgroundColor.withOpacity(0.3),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Error message
        if (_errorMessage != null && _searchController.text.isNotEmpty)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.accentColor,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Loading indicator
        if (_isSearching)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Searching...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

