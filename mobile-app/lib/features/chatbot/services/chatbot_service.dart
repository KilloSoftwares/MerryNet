import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'intelligent_algorithms.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}

class TrafficData {
  final double downloadSpeed;
  final double uploadSpeed;
  final double dataUsed;
  final Duration timeLeft;
  final bool isConnected;

  TrafficData({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.dataUsed,
    required this.timeLeft,
    required this.isConnected,
  });

  Map<String, dynamic> toJson() => {
        'downloadSpeed': downloadSpeed,
        'uploadSpeed': uploadSpeed,
        'dataUsed': dataUsed,
        'timeLeft': timeLeft.inMinutes,
        'isConnected': isConnected,
      };

  String get downloadSpeedFormatted => '${downloadSpeed.toStringAsFixed(1)} Mbps';
  String get uploadSpeedFormatted => '${uploadSpeed.toStringAsFixed(1)} Mbps';
  String get dataUsedFormatted => '${dataUsed.toStringAsFixed(1)} GB';
  String get timeLeftFormatted => '${timeLeft.inHours}h ${timeLeft.inMinutes.remainder(60)}m';
}

class ChatbotService extends ChangeNotifier {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  
  // Free models available on OpenRouter
  static const List<Map<String, String>> availableModels = [
    {'id': 'openai/gpt-3.5-turbo', 'name': 'GPT-3.5 Turbo (OpenAI)'},
    {'id': 'google/gemma-2-9b-it:free', 'name': 'Gemma 2 9B (Google) - Free'},
    {'id': 'meta-llama/llama-3-8b-instruct:free', 'name': 'Llama 3 8B (Meta) - Free'},
    {'id': 'mistralai/mistral-7b-instruct:free', 'name': 'Mistral 7B Instruct - Free'},
    {'id': 'microsoft/phi-3-mini-128k-instruct:free', 'name': 'Phi-3 Mini (Microsoft) - Free'},
    {'id': 'qwen/qwen-2-7b-instruct:free', 'name': 'Qwen 2 7B (Alibaba) - Free'},
  ];
  
  final List<ChatMessage> _messages = [];
  TrafficData? _currentTrafficData;
  bool _isLoading = false;
  String? _error;
  String _apiKey = '';
  String _selectedModel = 'google/gemma-2-9b-it:free';
  
  // Intelligent algorithms
  final NetworkMonitor _networkMonitor = NetworkMonitor();
  final SatisfactionTracker _satisfactionTracker = SatisfactionTracker();

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  TrafficData? get currentTrafficData => _currentTrafficData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get apiKey => _apiKey;
  String get selectedModel => _selectedModel;
  List<Map<String, String>> get models => availableModels;
  
  // Intelligent algorithm status
  NetworkStatus get networkStatus => _networkMonitor.getStatus();
  SatisfactionStatus get satisfactionStatus => _satisfactionTracker.getStatus();

  // Simulated traffic data - in production, this would come from your API
  void updateTrafficData(TrafficData data) {
    _currentTrafficData = data;
    notifyListeners();
  }

  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;

    // Add user message
    addMessage(ChatMessage(role: 'user', content: userMessage));
    
    _isLoading = true;
    _error = null;
    final startTime = DateTime.now();
    notifyListeners();

    try {
      // ── PHASE 0: Local Intelligent Pre-Processing ──
      final sentiment = IntelligentAlgorithms.analyzeSentiment(userMessage);
      final topics = IntelligentAlgorithms.extractTopics(userMessage);
      final uncertainty = IntelligentAlgorithms.estimateUncertainty(userMessage);
      final strategies = IntelligentAlgorithms.determineResponseStrategy(
        userMessage, sentiment, topics, uncertainty,
      );
      
      debugPrint('INTELLIGENCE: Sentiment=${sentiment.emotionalTone} | Topics=${topics.map((t) => t.topic).join(", ")} | Uncertainty=${uncertainty.toStringAsFixed(2)}');
      debugPrint('STRATEGY: ${strategies.map((s) => s.type).join(", ")}');

      // Build system prompt with current traffic data and intelligent analysis
      final systemPrompt = _buildSystemPrompt();
      
      // Get response from OpenRouter
      final response = await _callOpenRouter(systemPrompt, userMessage);
      
      // Track satisfaction
      final responseTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();
      final quality = IntelligentAlgorithms.scoreResponseQuality(response, userMessage);
      _satisfactionTracker.recordInteraction(userMessage, response, responseTime, quality);
      
      final satStatus = _satisfactionTracker.getStatus();
      debugPrint('SATISFACTION: Score=${satStatus.satisfaction}% | Trend=${satStatus.trend}');
      
      // Add assistant response
      addMessage(ChatMessage(role: 'assistant', content: response));
    } catch (e) {
      _error = e.toString();
      _networkMonitor.recordError();
      debugPrint('ERROR: ${e.toString()}');
      // Add error message
      addMessage(ChatMessage(
        role: 'assistant', 
        content: 'Sorry, I encountered an error: $e. Please try again.',
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _buildSystemPrompt() {
    final trafficInfo = _currentTrafficData != null 
        ? '''
Current Network Status:
- Connection Status: ${_currentTrafficData!.isConnected ? 'Connected' : 'Disconnected'}
- Download Speed: ${_currentTrafficData!.downloadSpeedFormatted}
- Upload Speed: ${_currentTrafficData!.uploadSpeedFormatted}
- Data Used: ${_currentTrafficData!.dataUsedFormatted}
- Time Remaining: ${_currentTrafficData!.timeLeftFormatted}
'''
        : 'No current traffic data available.';

    return '''You are Maranet Assistant, a helpful AI chatbot for the Maranet Zero VPN service. Your role is to:

1. Help users understand their network usage and traffic data
2. Answer questions about their VPN connection and data usage
3. Provide recommendations for plan upgrades based on usage patterns
4. Assist with general inquiries about the service

Current Traffic Data:
$trafficInfo

Guidelines:
- Be friendly and concise
- Use the traffic data to provide personalized responses
- If asked about upgrading, suggest appropriate plans based on usage
- If you don't have current data, let the user know politely
- Keep responses under 3-4 sentences when possible
- You are in FREE MODE - provide helpful assistance without requiring payment''';
  }

  Future<String> _callOpenRouter(String systemPrompt, String userMessage) async {
    // Use instance API key or fall back to environment
    final apiKey = _apiKey.isNotEmpty ? _apiKey : const String.fromEnvironment('OPENROUTER_API_KEY');
    
    if (apiKey.isEmpty) {
      // Return a simulated response for development
      return _getSimulatedResponse(userMessage);
    }

    final startTime = DateTime.now();
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://maranet.app',
          'X-Title': 'Maranet Assistant',
        },
        body: jsonEncode({
          'model': _selectedModel, // Use selected model
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      );

      final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();
      _networkMonitor.recordLatency(latency);

      if (response.statusCode == 200) {
        _networkMonitor.recordSuccess();
        debugPrint('NETWORK: ✓ Success | Latency: ${latency.round()}ms | Quality: ${(_networkMonitor.getStatus().quality * 100).round()}%');
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        _networkMonitor.recordError();
        debugPrint('NETWORK: ✗ Error ${response.statusCode} | Latency: ${latency.round()}ms');
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();
      _networkMonitor.recordLatency(latency);
      _networkMonitor.recordError();
      debugPrint('NETWORK: ✗ Connection error | Status: ${_networkMonitor.getStatus().status}');
      rethrow;
    }
  }

  String _getSimulatedResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.contains('data') || lowerMessage.contains('usage')) {
      if (_currentTrafficData != null) {
        return 'You\'ve used ${_currentTrafficData!.dataUsedFormatted} this session. Your current download speed is ${_currentTrafficData!.downloadSpeedFormatted}. Based on your usage, you might want to consider our Weekly plan for better value!';
      }
      return 'I don\'t have your current usage data. Please make sure you\'re connected to the VPN.';
    }
    
    if (lowerMessage.contains('speed') || lowerMessage.contains('fast')) {
      if (_currentTrafficData != null) {
        return 'Your current speeds: Download ${_currentTrafficData!.downloadSpeedFormatted}, Upload ${_currentTrafficData!.uploadSpeedFormatted}. These are good speeds for streaming and browsing!';
      }
      return 'I can\'t check speeds right now. Please ensure you\'re connected to the VPN.';
    }
    
    if (lowerMessage.contains('plan') || lowerMessage.contains('upgrade')) {
      return 'We offer various plans: 2 Hours (KES 10), Daily (KES 80), Weekly (KES 350), and Monthly (KES 700). The Monthly plan offers the best value with priority support!';
    }
    
    if (lowerMessage.contains('time') || lowerMessage.contains('left')) {
      if (_currentTrafficData != null) {
        return 'You have ${_currentTrafficData!.timeLeftFormatted} remaining on your current session. Consider upgrading to a longer plan for uninterrupted access!';
      }
      return 'I don\'t have information about your remaining time. Please check your profile.';
    }
    
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return 'Hello! I\'m your Maranet Assistant. I can help you monitor your traffic, answer questions about your usage, and suggest the best plans. How can I assist you today?';
    }
    
    return 'I\'m here to help with your Maranet experience! You can ask me about your data usage, connection speeds, available plans, or anything else. What would you like to know?';
  }

  void simulateTrafficUpdate() {
    // Simulate real-time traffic updates
    _currentTrafficData = TrafficData(
      downloadSpeed: 30 + (DateTime.now().millisecond / 10),
      uploadSpeed: 10 + (DateTime.now().millisecond / 20),
      dataUsed: 2.0 + (DateTime.now().second / 60),
      timeLeft: Duration(hours: 18, minutes: 32 - DateTime.now().second),
      isConnected: true,
    );
    notifyListeners();
  }

  void setApiKey(String key) {
    _apiKey = key;
    notifyListeners();
  }

  void setSelectedModel(String modelId) {
    _selectedModel = modelId;
    notifyListeners();
  }

  bool get hasApiKey => _apiKey.isNotEmpty;
}
