import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/server_config.dart';
import '../../../core/network/api_client.dart';

class DeveloperModeScreen extends ConsumerStatefulWidget {
  const DeveloperModeScreen({super.key});

  @override
  ConsumerState<DeveloperModeScreen> createState() => _DeveloperModeScreenState();
}

class _DeveloperModeScreenState extends ConsumerState<DeveloperModeScreen> {
  bool _isTesting = false;
  ConnectionTestResult? _lastTestResult;
  
  // Controllers for custom endpoint
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _apiPathController = TextEditingController();
  final _bootstrapPortController = TextEditingController();
  bool _useTls = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _apiPathController.dispose();
    _bootstrapPortController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Initialize server config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serverConfigProvider).initialize();
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _lastTestResult = null;
    });

    try {
      final config = ref.read(serverConfigProvider);
      final result = await config.testConnection();
      setState(() {
        _lastTestResult = result;
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _lastTestResult = ConnectionTestResult(
          success: false,
          latency: 0,
          message: 'Connection failed: ${e.toString()}',
        );
        _isTesting = false;
      });
    }
  }

  void _saveCustomEndpoint() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;
    final apiPath = _apiPathController.text.trim();
    final bootstrapPort = int.tryParse(_bootstrapPortController.text.trim()) ?? 8081;

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a host address')),
      );
      return;
    }

    final endpoint = ServerEndpoint(
      name: 'Custom Server',
      apiBaseUrl: 'http${_useTls ? 's' : ''}://$host:$port$apiPath',
      bootstrapUrl: 'http${_useTls ? 's' : ''}://$host:$bootstrapPort',
      grpcHost: host,
      grpcPort: 50051,
      useTls: _useTls,
      description: 'Custom developer server',
    );

    ref.read(serverConfigProvider).setCustomEndpoint(endpoint);
    ref.read(serverConfigProvider).setServerMode(ServerMode.reseller);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom endpoint saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = ref.watch(serverConfigProvider);
    final currentEndpoint = ref.watch(currentEndpointProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Mode'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              serverConfig.toggleDeveloperMode();
            },
            tooltip: serverConfig.developerModeEnabled 
                ? 'Disable Developer Mode' 
                : 'Enable Developer Mode',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Developer Mode Toggle Card
          _buildDeveloperModeCard(serverConfig),
          
          const SizedBox(height: 16),

          // Current Connection Info
          _buildConnectionInfoCard(currentEndpoint),
          
          const SizedBox(height: 16),

          // Server Mode Selection
          _buildServerModeCard(serverConfig),
          
          const SizedBox(height: 16),

          // Custom Endpoint Configuration (shown when reseller mode is selected)
          if (serverConfig.currentMode == ServerMode.reseller)
            _buildCustomEndpointCard(),
          
          const SizedBox(height: 16),

          // Connection Test
          _buildConnectionTestCard(),
          
          const SizedBox(height: 16),

          // Reset to Defaults
          _buildResetCard(serverConfig),
        ],
      ),
    );
  }

  Widget _buildDeveloperModeCard(ServerConfig config) {
    return Card(
      color: config.developerModeEnabled 
          ? Colors.green.withOpacity(0.1) 
          : Colors.grey.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.developer_mode,
                  color: config.developerModeEnabled 
                      ? Colors.green 
                      : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Developer Mode',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        config.developerModeEnabled
                            ? 'Enabled - Debug features active'
                            : 'Disabled - Production mode',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: config.developerModeEnabled,
                  onChanged: (value) {
                    config.setDeveloperModeEnabled(value);
                  },
                ),
              ],
            ),
            if (config.developerModeEnabled) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Developer mode enables:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              _buildFeatureItem('Server switching'),
              _buildFeatureItem('Debug logging'),
              _buildFeatureItem('Connection testing'),
              _buildFeatureItem('Custom endpoints'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildConnectionInfoCard(ServerEndpoint endpoint) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 12),
                Text(
                  'Current Connection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Server', endpoint.name),
            _buildInfoRow('API URL', endpoint.apiBaseUrl),
            _buildInfoRow('Bootstrap', endpoint.bootstrapUrl),
            if (endpoint.grpcHost != null)
              _buildInfoRow('gRPC', '${endpoint.grpcHost}:${endpoint.grpcPort}'),
            _buildInfoRow('TLS', endpoint.useTls ? 'Enabled' : 'Disabled'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerModeCard(ServerConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildModeOption(
              'Local Development',
              'Connect to localhost:3000',
              ServerMode.local,
              config,
            ),
            _buildModeOption(
              'Main Server (Production)',
              'Connect to production server',
              ServerMode.mainServer,
              config,
            ),
            _buildModeOption(
              'Reseller Agent',
              'Connect to custom reseller server',
              ServerMode.reseller,
              config,
            ),
            _buildModeOption(
              'Auto Detect',
              'Automatically detect available servers',
              ServerMode.auto,
              config,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(
    String title,
    String subtitle,
    ServerMode mode,
    ServerConfig config,
  ) {
    final isSelected = config.currentMode == mode;
    return RadioListTile<ServerMode>(
      value: mode,
      groupValue: config.currentMode,
      onChanged: (value) {
        config.setServerMode(value!);
      },
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      secondary: isSelected
          ? const Icon(Icons.radio_button_checked, color: Colors.blue)
          : const Icon(Icons.radio_button_unchecked),
    );
  }

  Widget _buildCustomEndpointCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Remote Server Configuration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure your remote server details below:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Server Host/IP',
                hintText: 'e.g., 203.0.113.50 or reseller.example.com',
                prefixIcon: Icon(Icons.public),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'API Port',
                      hintText: '3000',
                      prefixIcon: Icon(Icons.portable_wifi_off),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _bootstrapPortController,
                    decoration: const InputDecoration(
                      labelText: 'Bootstrap Port',
                      hintText: '8080',
                      prefixIcon: Icon(Icons.router),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiPathController,
              decoration: const InputDecoration(
                labelText: 'API Path',
                hintText: '/api/v1',
                prefixIcon: Icon(Icons.http),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _useTls,
                  onChanged: (value) {
                    setState(() {
                      _useTls = value ?? false;
                    });
                  },
                ),
                const Text('Use TLS/HTTPS'),
                const SizedBox(width: 16),
                if (_useTls)
                  const Icon(Icons.lock, color: Colors.green, size: 16)
                else
                  const Icon(Icons.lock_open, color: Colors.orange, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveCustomEndpoint,
              icon: const Icon(Icons.save),
              label: const Text('Save & Connect'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connection Test',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_isTesting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_lastTestResult != null)
              _buildTestResult(_lastTestResult!)
            else
              const Text(
                'Test connection to verify server is reachable',
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: const Icon(Icons.wifi_find),
              label: const Text('Test Connection'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResult(ConnectionTestResult result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success 
            ? Colors.green.withOpacity(0.1) 
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error,
            color: result.success ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.message,
                  style: TextStyle(
                    color: result.success ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (result.latency > 0)
                  Text(
                    'Latency: ${result.latency}ms',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetCard(ServerConfig config) {
    return Card(
      color: Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 12),
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Reset all developer settings to default values',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await config.resetToDefaults();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings reset to defaults')),
                  );
                }
              },
              icon: const Icon(Icons.restore, color: Colors.red),
              label: const Text(
                'Reset to Defaults',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}