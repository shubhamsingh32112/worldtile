/// Maps state names to state keys
/// This is used to extract stateKey from GeoJSON feature properties
class StateKeyMapper {
  static const Map<String, String> stateNameToKey = {
    'Karnataka': 'karnataka',
    'Maharashtra': 'maharashtra',
    'Delhi': 'delhi',
    'Telangana': 'telangana',
    'West Bengal': 'west_bengal',
    'Rajasthan': 'rajasthan',
    'Kerala': 'kerala',
    'Tamil Nadu': 'tamil_nadu',
  };

  /// Get stateKey from state name
  /// Returns null if state name is not found
  static String? getStateKey(String? stateName) {
    if (stateName == null) return null;
    
    // Try exact match first
    if (stateNameToKey.containsKey(stateName)) {
      return stateNameToKey[stateName];
    }
    
    // Try case-insensitive match
    for (final entry in stateNameToKey.entries) {
      if (entry.key.toLowerCase() == stateName.toLowerCase()) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Extract stateKey from GeoJSON feature properties
  /// Looks for common property names like NAME_1, NAME_0, etc.
  static String? extractStateKeyFromFeature(Map<String, dynamic>? properties) {
    if (properties == null) return null;
    
    // Try common GADM property names
    final possibleKeys = ['NAME_1', 'NAME_0', 'name', 'state', 'stateName', 'state_name'];
    
    for (final key in possibleKeys) {
      final value = properties[key];
      if (value is String) {
        final stateKey = getStateKey(value);
        if (stateKey != null) {
          return stateKey;
        }
      }
    }
    
    // Try direct stateKey property
    if (properties.containsKey('stateKey')) {
      return properties['stateKey'] as String?;
    }
    
    return null;
  }
}

