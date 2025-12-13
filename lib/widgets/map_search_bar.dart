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

  /// Callback when search is cleared
  /// Used to reset map to default view
  final VoidCallback? onSearchCleared;

  /// Optional placeholder text
  final String? hintText;

  const MapSearchBar({
    super.key,
    required this.onPlaceSelected,
    this.onSearchCleared,
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
    // Don't show results dropdown - suggestions are disabled
    setState(() {
      _showResults = false;
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
      // Notify parent to reset map view when search is cleared
      if (widget.onSearchCleared != null) {
        widget.onSearchCleared!();
      }
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
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    // Store the query we're searching for to avoid race conditions
    final searchQuery = trimmedQuery;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    final result = await GeocodingService.searchPlaces(searchQuery, limit: 5);

    if (!mounted) return;
    
    // Verify the query hasn't changed while we were searching
    final currentQuery = _searchController.text.trim();
    if (currentQuery != searchQuery) {
      // Query changed, ignore these results
      return;
    }

    setState(() {
      _isSearching = false;
      if (result['success'] == true) {
        _searchResults = result['places'] as List<PlaceResult>;
        _showResults = false; // Don't show suggestions dropdown
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
    // Notify parent to reset map view
    if (widget.onSearchCleared != null) {
      widget.onSearchCleared!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
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
            onSubmitted: (value) async {
              final query = value.trim();
              if (query.isEmpty) return;
              
              // If there are existing results and query matches, use first result
              if (_searchResults.isNotEmpty) {
                _selectPlace(_searchResults.first);
                return;
              }
              
              // Otherwise, trigger immediate search and wait for results
              if (_isSearching) {
                // Wait for current search to complete
                await Future.delayed(const Duration(milliseconds: 600));
              } else {
                // Trigger immediate search
                await _performSearch(query);
              }
              
              // Select first result if available
              if (mounted && _searchResults.isNotEmpty) {
                _selectPlace(_searchResults.first);
              }
            },
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

