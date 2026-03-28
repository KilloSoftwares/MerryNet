import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import '../../core/network/api_client.dart';

/// VPN connection states
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// VPN connection details
class VpnConnectionInfo {
  final String serverIp;
  final String serverLocation;
  final String protocol;
  final String assignedIp;
  final DateTime connectedAt;
  final DateTime expiresAt;

  VpnConnectionInfo({
    required this.serverIp,
    required this.serverLocation,
    required this.protocol,
    required this.assignedIp,
    required this.connectedAt,
    required this.expiresAt,
  });

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// VPN configuration received from the server
class VpnConfig {
  final String privateKey;
  final String publicKey;
  final String address;
  final String dns;
  final String endpoint;
  final String serverPublicKey;
  final int keepalive;
  final int mtu;

  VpnConfig({
    required this.privateKey,
    required this.publicKey,
    required this.address,
    required this.dns,
    required this.endpoint,
    required this.serverPublicKey,
    required this.keepalive,
    required this.mtu,
  });

  factory VpnConfig.fromJson(Map<String, dynamic> json) {
    return VpnConfig(
      privateKey: json['privateKey'] as String,
      publicKey: json['publicKey'] as String,
      address: json['address'] as String,
      dns: json['dns'] as String? ?? '1.1.1.1, 8.8.8.8',
      endpoint: json['endpoint'] as String,
      serverPublicKey: json['serverPublicKey'] as String,
      keepalive: json['keepalive'] as int? ?? 25,
      mtu: json['mtu'] as int? ?? 1420,
    );
  }

  /// Generate WireGuard INI configuration string
  String toWireGuardConfig() {
    return '''
[Interface]
PrivateKey = $privateKey
Address = $address
DNS = $dns
MTU = $mtu

[Peer]
PublicKey = $serverPublicKey
Endpoint = $endpoint
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = $keepalive
''';
  }
}

/// VPN state management
class VpnState {
  final VpnStatus status;
  final VpnConnectionInfo? connectionInfo;
  final String? errorMessage;
  final int bytesIn;
  final int bytesOut;

  VpnState({
    this.status = VpnStatus.disconnected,
    this.connectionInfo,
    this.errorMessage,
    this.bytesIn = 0,
    this.bytesOut = 0,
  });

  VpnState copyWith({
    VpnStatus? status,
    VpnConnectionInfo? connectionInfo,
    String? errorMessage,
    int? bytesIn,
    int? bytesOut,
  }) {
    return VpnState(
      status: status ?? this.status,
      connectionInfo: connectionInfo ?? this.connectionInfo,
      errorMessage: errorMessage ?? this.errorMessage,
      bytesIn: bytesIn ?? this.bytesIn,
      bytesOut: bytesOut ?? this.bytesOut,
    );
  }
}

/// VPN service controller
class VpnNotifier extends StateNotifier<VpnState> {
  final FlutterSecureStorage _storage;

  VpnNotifier(this._storage) : super(VpnState());

  /// Connect to VPN
  Future<void> connect() async {
    if (state.status == VpnStatus.connecting || state.status == VpnStatus.connected) {
      return;
    }

    state = state.copyWith(status: VpnStatus.connecting, errorMessage: null);

    try {
      // Load saved VPN config
      final configStr = await _storage.read(key: 'vpn_config');
      if (configStr == null) {
        state = state.copyWith(
          status: VpnStatus.error,
          errorMessage: 'No VPN configuration found. Please purchase a plan first.',
        );
        return;
      }

      // Connect via wireguard_flutter plugin
      final wireguard = WireGuardFlutter.instance;
      await wireguard.initialize(tunnelName: 'MaranetZero');
      await wireguard.startVpn(
        serverAddress: 'tunnel.maranet.app',
        wgQuickConfig: configStr,
        providerBundleIdentifier: 'com.maranet.zero.wireguard',
      );

      state = state.copyWith(
        status: VpnStatus.connected,
        connectionInfo: VpnConnectionInfo(
          serverIp: '10.0.1.1',
          serverLocation: 'Nairobi, Kenya',
          protocol: 'WireGuard',
          assignedIp: '10.0.1.42',
          connectedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        ),
      );
    } catch (e) {
      state = state.copyWith(
        status: VpnStatus.error,
        errorMessage: 'Connection failed: ${e.toString()}',
      );
    }
  }

  /// Disconnect from VPN
  Future<void> disconnect() async {
    if (state.status != VpnStatus.connected) return;

    state = state.copyWith(status: VpnStatus.disconnecting);

    try {
      // Stop tunnel via wireguard_flutter plugin
      final wireguard = WireGuardFlutter.instance;
      await wireguard.stopVpn();

      state = VpnState(status: VpnStatus.disconnected);
    } catch (e) {
      state = state.copyWith(
        status: VpnStatus.error,
        errorMessage: 'Disconnect failed: ${e.toString()}',
      );
    }
  }

  /// Toggle VPN connection
  Future<void> toggle() async {
    if (state.status == VpnStatus.connected) {
      await disconnect();
    } else {
      await connect();
    }
  }

  /// Save VPN configuration
  Future<void> saveConfig(VpnConfig config) async {
    await _storage.write(key: 'vpn_config', value: config.toWireGuardConfig());
    await _storage.write(key: 'vpn_endpoint', value: config.endpoint);
    await _storage.write(key: 'vpn_address', value: config.address);
  }

  /// Update traffic stats
  void updateStats(int bytesIn, int bytesOut) {
    state = state.copyWith(bytesIn: bytesIn, bytesOut: bytesOut);
  }
}

// Providers
final vpnProvider = StateNotifierProvider<VpnNotifier, VpnState>((ref) {
  return VpnNotifier(ref.watch(secureStorageProvider));
});
