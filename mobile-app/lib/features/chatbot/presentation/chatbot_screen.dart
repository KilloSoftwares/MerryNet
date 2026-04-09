import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/chatbot_service.dart';

// Provider for the chatbot service
final chatbotServiceProvider = ChangeNotifierProvider((ref) => ChatbotService());

// Provider for real-time traffic updates
final trafficUpdateProvider = StreamProvider<TrafficData>((ref) {
  return Stream.periodic(const Duration(seconds: 3), (_) {
    final service = ref.read(chatbotServiceProvider);
    service.simulateTrafficUpdate();
    return service.currentTrafficData ?? TrafficData(
      downloadSpeed: 0,
      uploadSpeed: 0,
      dataUsed: 0,
      timeLeft: Duration.zero,
      isConnected: false,
    );
  });
});

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize with welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(chatbotServiceProvider);
      if (service.messages.isEmpty) {
        service.addMessage(ChatMessage(
          role: 'assistant',
          content: 'Hello! I\'m your Maranet AI Assistant. I can help you monitor your traffic, answer questions about your usage, and suggest the best plans. How can I assist you today?',
        ));
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final service = ref.read(chatbotServiceProvider);
    service.sendMessage(_messageController.text.trim());
    _messageController.clear();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatbotService = ref.watch(chatbotServiceProvider);
    final trafficAsync = ref.watch(trafficUpdateProvider);

    // Update traffic data when available
    trafficAsync.whenData((data) {
      chatbotService.updateTrafficData(data);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, size: 24),
            SizedBox(width: 8),
            Text('AI Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => chatbotService.clearMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Traffic Status Banner
          if (chatbotService.currentTrafficData != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceLight,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: chatbotService.currentTrafficData!.isConnected
                          ? AppColors.success
                          : AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '↓ ${chatbotService.currentTrafficData!.downloadSpeedFormatted}  ↑ ${chatbotService.currentTrafficData!.uploadSpeedFormatted}  Used: ${chatbotService.currentTrafficData!.dataUsedFormatted}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatbotService.messages.length,
              itemBuilder: (context, index) {
                final message = chatbotService.messages[index];
                final isUser = message.role == 'user';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: isUser
                                ? null
                                : Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              color: isUser ? Colors.white : AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_rounded, color: AppColors.textMuted, size: 20),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Loading indicator
          if (chatbotService.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('AI is typing...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.surfaceLight, width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Ask about your usage, speeds, or plans...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Assistant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('I\'m your Maranet AI Assistant, here to help you with:'),
            const SizedBox(height: 8),
            const Text('• Monitoring your traffic and usage'),
            const Text('• Answering questions about speeds'),
            const Text('• Suggesting the best plans for your needs'),
            const Text('• General inquiries about the service'),
            const SizedBox(height: 12),
            const Text('Powered by OpenRouter AI', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final service = ref.read(chatbotServiceProvider);
    final apiKeyController = TextEditingController(text: service.apiKey);
    String selectedModel = service.selectedModel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Chatbot Settings'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // API Key Input
                const Text('OpenRouter API Key', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'sk-or-v1-...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.key),
                  ),
                ),
                const SizedBox(height: 16),
                // Model Selection
                const Text('AI Model', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...service.models.map((model) => RadioListTile<String>(
                  title: Text(model['name']!, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(model['id']!, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  value: model['id']!,
                  groupValue: selectedModel,
                  onChanged: (value) {
                    setDialogState(() => selectedModel = value!);
                  },
                  contentPadding: EdgeInsets.zero,
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                service.setApiKey(apiKeyController.text.trim());
                service.setSelectedModel(selectedModel);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Settings saved! Using ${service.models.firstWhere((m) => m['id'] == selectedModel)['name']}'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
