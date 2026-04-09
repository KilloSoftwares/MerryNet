import { Request, Response } from 'express';
import {
  IntelligentAlgorithmsService,
  analyzeInput,
  scoreResponseQuality,
} from '../services/intelligent-algorithms.service';

interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

interface ChatRequest {
  message: string;
  conversationHistory?: ChatMessage[];
  userId?: string;
}

interface ChatResponse {
  response: string;
  intelligence: {
    sentiment: string;
    topics: string[];
    uncertainty: number;
    strategies: string[];
  };
  network: {
    status: string;
    quality: number;
    latency: number;
  };
  satisfaction: {
    score: number;
    trend: string;
  };
  timestamp: string;
}

/**
 * Chatbot Controller
 * Handles chat requests with intelligent pre-processing
 */
export class ChatbotController {
  /**
   * Process a chat message with intelligent algorithms
   */
  async processMessage(req: Request, res: Response): Promise<void> {
    const startTime = performance.now();
    const { message, conversationHistory = [], userId }: ChatRequest = req.body;

    if (!message || message.trim() === '') {
      res.status(400).json({ error: 'Message is required' });
      return;
    }

    try {
      // ── PHASE 0: Local Intelligent Pre-Processing ──
      const intelligence = analyzeInput(message);

      console.log(`[CHATBOT] Intelligence Analysis:`, {
        sentiment: intelligence.sentiment.emotionalTone,
        topics: intelligence.topics.map(t => t.topic),
        uncertainty: intelligence.uncertainty.toFixed(2),
        strategies: intelligence.strategies.map(s => s.type),
      });

      // ── PHASE 1: Generate Response ──
      const response = await this.generateResponse(message, conversationHistory, intelligence);

      // ── PHASE 2: Track Metrics ──
      const responseTime = performance.now() - startTime;
      const quality = scoreResponseQuality(response, message);
      IntelligentAlgorithmsService.recordInteraction(message, response, responseTime, quality);

      const networkStatus = IntelligentAlgorithmsService.getNetworkStatus();
      const satisfactionStatus = IntelligentAlgorithmsService.getSatisfactionStatus();

      IntelligentAlgorithmsService.recordNetworkLatency(responseTime);
      IntelligentAlgorithmsService.recordNetworkSuccess();

      const chatResponse: ChatResponse = {
        response,
        intelligence: {
          sentiment: intelligence.sentiment.emotionalTone,
          topics: intelligence.topics.map(t => t.topic),
          uncertainty: intelligence.uncertainty,
          strategies: intelligence.strategies.map(s => s.type),
        },
        network: {
          status: networkStatus.status,
          quality: networkStatus.quality,
          latency: networkStatus.avgLatency,
        },
        satisfaction: {
          score: satisfactionStatus.satisfaction,
          trend: satisfactionStatus.trend,
        },
        timestamp: new Date().toISOString(),
      };

      res.json(chatResponse);
    } catch (error) {
      IntelligentAlgorithmsService.recordNetworkError();
      console.error('[CHATBOT] Error:', error);
      res.status(500).json({
        error: 'Failed to process message',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }

  /**
   * Generate response based on intelligent analysis
   */
  private async generateResponse(
    message: string,
    _conversationHistory: ChatMessage[],
    intelligence: any
  ): Promise<string> {
    const lowerMessage = message.toLowerCase();

    // Simulate API latency
    await new Promise(resolve => setTimeout(resolve, 300 + Math.random() * 500));

    // Intelligent responses based on detected topics and sentiment
    if (intelligence.topics.some((t: { topic: string }) => t.topic === 'networking')) {
      if (lowerMessage.includes('data') || lowerMessage.includes('usage')) {
        return "Based on your current usage patterns, you've consumed approximately 2.5GB this session. Your average download speed is 45 Mbps. For heavy usage like yours, I'd recommend our Weekly plan for better value!";
      }

      if (lowerMessage.includes('speed') || lowerMessage.includes('fast')) {
        return "Your current connection is performing well! Download: 45 Mbps, Upload: 12 Mbps. These speeds are excellent for streaming HD content and video calls. Is there anything specific you'd like to optimize?";
      }

      if (lowerMessage.includes('vpn') || lowerMessage.includes('connection')) {
        return "Your VPN connection is active and secure. MerryNet's intelligent routing ensures optimal performance while maintaining your privacy. Current latency is within normal range.";
      }
    }

    if (lowerMessage.includes('plan') || lowerMessage.includes('upgrade') || lowerMessage.includes('price')) {
      return "Here are our available plans:\n\n• 2 Hours - KES 10\n• Daily - KES 80\n• Weekly - KES 350 (Best Value!)\n• Monthly - KES 700\n\nThe Weekly plan offers the best value with priority support and unlimited data. Would you like me to help you upgrade?";
    }

    if (lowerMessage.includes('time') || lowerMessage.includes('left') || lowerMessage.includes('expire')) {
      return "You currently have 18 hours and 32 minutes remaining on your session. Your plan will expire tomorrow at 10:30 AM. Consider upgrading to a longer plan for uninterrupted access!";
    }

    if (lowerMessage.includes('hello') || lowerMessage.includes('hi') || lowerMessage.includes('hey')) {
      return "Hello! 👋 I'm your MerryNet AI Assistant, powered by intelligent algorithms that understand your needs. I can help you monitor your network, check usage, suggest plans, or answer any questions. What would you like to know?";
    }

    if (lowerMessage.includes('help') || lowerMessage.includes('support')) {
      return "I'm here to help! I can assist you with:\n\n• Checking your data usage and speeds\n• Recommending the best plan for your needs\n• Troubleshooting connection issues\n• Answering questions about our service\n\nWhat would you like help with?";
    }

    // Default intelligent response
    return "I understand you're asking about that. Let me help you with your MerryNet experience. You can ask me about your data usage, connection speeds, available plans, or any technical issues. I'm here to make your internet experience seamless!";
  }

  /**
   * Get network status
   */
  getNetworkStatus(req: Request, res: Response): void {
    const status = IntelligentAlgorithmsService.getNetworkStatus();
    res.json(status);
  }

  /**
   * Get satisfaction status
   */
  getSatisfactionStatus(req: Request, res: Response): void {
    const status = IntelligentAlgorithmsService.getSatisfactionStatus();
    res.json(status);
  }

  /**
   * Submit feedback
   */
  submitFeedback(req: Request, res: Response): void {
    const { score, comment } = req.body;

    if (score === undefined || score < 1 || score > 5) {
      res.status(400).json({ error: 'Score must be between 1 and 5' });
      return;
    }

    IntelligentAlgorithmsService.recordFeedback(score, comment || '');
    res.json({ success: true, message: 'Feedback recorded' });
  }

  /**
   * Analyze text (standalone endpoint for testing)
   */
  analyzeText(req: Request, res: Response): void {
    const { text } = req.body;

    if (!text || text.trim() === '') {
      res.status(400).json({ error: 'Text is required' });
      return;
    }

    const analysis = analyzeInput(text);
    res.json(analysis);
  }
}

export const chatbotController = new ChatbotController();