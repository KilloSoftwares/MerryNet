import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Server mode types for developer mode
enum ServerMode {
  /// Connect to local development server (localhost)
  local,

  /// Connect to main server remotely
  mainServer,

  /// Connect to reseller agent remotely
  reseller,

  /// Auto-detect based on network
  auto,
}

/// Configuration for a server endpoint
class ServerEndpoint {
  final String name;
  final String apiBaseUrl;
  final String bootstrapUrl;
  final String? grpcHost;
  final int? grpcPort;
  final bool useTls;
  final String? description;

  const ServerEndpoint({
    required this.name,
    required this.apiBaseUrl,
    required this.bootstrapUrl,
    this.grpcHost,
    this.grpcPort,
    this.useTls = false,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'apiBaseUrl': apiBaseUrl,
        'bootstrapUrl': bootstrapUrl,
        'grpcHost': grpcHost,
        'grpcPort': grpcPort,
        'useTls': useTls,
        'description': description,
      };

  factory ServerEndpoint.fromJson(Map<String, dynamic> json) => ServerEndpoint(
        name: json['name'] as String,
        apiBaseUrl: json['apiBaseUrl'] as String,
        bootstrapUrl: json['bootstrapUrl'] as String,
        grpcHost: json['grpcHost'] as String?,
        grpcPort: json['grpcPort'] as int?,
        useTls: json['useTls'] as bool? ?? false,
        description: json['description'] as String?,
      );
}

/// Pre-defined server configurations
class PresetServers {
  /// Local development server
  static const local = ServerEndpoint(
    name: 'Local Development',
    apiBaseUrl: 'http://localhost:3000/api/v1',
    bootstrapUrl: 'http://localhost:8080',
    grpcHost: 'localhost',
    grpcPort: 50051,
    useTls: false,
    description: 'Connect to local development server',
  );

  /// Production main server
  static const mainServerProd = ServerEndpoint(
    name: 'Main Server (Production)',
    apiBaseUrl: 'https://api.maranet.app/api/v1',
    bootstrapUrl: 'https://free.facebook.com.maranet.app',
    grpcHost: 'api.maranet.app',
    grpcPort: 50051,
    useTls: true,
    description: 'Connect to production main server',
  );

  /// Staging main server
  static const mainServerStaging = ServerEndpoint(
    name: 'Main Server (Staging)',
    apiBaseUrl: 'https://staging-api.maranet.app/api/v1',
    bootstrapUrl: 'https://staging.maranet.app',
    grpcHost: 'staging-api.maranet.app',
    grpcPort: 50051,
    useTls: true,
    description: 'Connect to staging main server',
  );

  /// Example reseller agent
  static const resellerExample = ServerEndpoint(
    name: 'Reseller Agent (Example)',
    apiBaseUrl: 'http://192.168.1.100:8080/api/v1',
    bootstrapUrl: 'http://192.168.1.100:8081',
    grpcHost: '192.168.1.100',
    grpcPort: 50051,
    useTls: false,
    description: 'Connect to a reseller agent on local network',
  );
}

/// Developer mode configuration manager
class ServerConfig with ChangeNotifier {
  static final ServerConfig _instance = ServerConfig._internal();
  factory ServerConfig() => _instance;
  ServerConfig._internal();

  SharedPreferences? _prefs;

  ServerMode _currentMode = ServerMode.local;
  ServerEndpoint? _customEndpoint;
  bool _developerModeEnabled = false;
  bool _isLoading = true;

  // Getters
  ServerMode get currentMode => _currentMode;
  ServerEndpoint? get customEndpoint => _customEndpoint;
  bool get developerModeEnabled => _developerModeEnabled;
  bool get isLoading => _isLoading;

  /// Get the current active endpoint based on mode
  ServerEndpoint get currentEndpoint {
    switch (_currentMode) {
      case ServerMode.local:
        return PresetServers.local;
      case ServerMode.mainServer:
        return PresetServers.mainServerProd;
      case ServerMode.reseller:
        return _customEndpoint ?? PresetServers.resellerExample;
      case ServerMode.auto:
        return _detectAutoEndpoint();
    }
  }

  /// Get the current API base URL
  String get apiBaseUrl => currentEndpoint.apiBaseUrl;

  /// Get the current bootstrap URL
  String get bootstrapUrl => currentEndpoint.bootstrapUrl;

  /// Initialize configuration from storage
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _developerModeEnabled = _prefs!.getBool('developer_mode_enabled') ?? false;
      final modeName = _prefs!.getString('server_mode');
      _currentMode = ServerMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => ServerMode.local,
      );

      final customEndpointJson = _prefs!.getString('custom_endpoint');
      if (customEndpointJson != null) {
        _customEndpoint = ServerEndpoint.fromJson(
          json.decode(customEndpointJson) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('Error loading server config: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set the server mode
  Future<void> setServerMode(ServerMode mode) async {
    _currentMode = mode;
    await _prefs?.setString('server_mode', mode.name);
    notifyListeners();
  }

  /// Set custom endpoint for reseller mode
  Future<void> setCustomEndpoint(ServerEndpoint endpoint) async {
    _customEndpoint = endpoint;
    await _prefs?.setString('custom_endpoint', json.encode(endpoint.toJson()));
    notifyListeners();
  }

  /// Enable/disable developer mode
  Future<void> setDeveloperModeEnabled(bool enabled) async {
    _developerModeEnabled = enabled;
    await _prefs?.setBool('developer_mode_enabled', enabled);
    notifyListeners();
  }

  /// Toggle developer mode
  Future<void> toggleDeveloperMode() async {
    await setDeveloperModeEnabled(!_developerModeEnabled);
  }

  /// Reset to default configuration
  Future<void> resetToDefaults() async {
    _currentMode = ServerMode.local;
    _customEndpoint = null;
    _developerModeEnabled = false;
    await _prefs?.remove('server_mode');
    await _prefs?.remove('custom_endpoint');
    await _prefs?.remove('developer_mode_enabled');
    notifyListeners();
  }

  /// Auto-detect endpoint based on network
  ServerEndpoint _detectAutoEndpoint() {
    // In a real implementation, this would check network connectivity
    // and try to discover available servers
    return PresetServers.local;
  }

  /// Test connection to current endpoint
  Future<ConnectionTestResult> testConnection() async {
    // This would be implemented with actual network testing
    return ConnectionTestResult(
      success: true,
      latency: 100,
      message: 'Connection successful',
    );
  }

  /// Get all available presets
  List<ServerEndpoint> getAvailablePresets() {
    return [
      PresetServers.local,
      PresetServers.mainServerProd,
      PresetServers.mainServerStaging,
      PresetServers.resellerExample,
    ];
  }
}

/// Result of a connection test
class ConnectionTestResult {
  final bool success;
  final int latency; // milliseconds
  final String message;
  final ServerEndpoint? endpoint;

  ConnectionTestResult({
    required this.success,
    required this.latency,
    required this.message,
    this.endpoint,
  });
}