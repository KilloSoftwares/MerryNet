/**
 * Cognitive Service - AI-powered features for MerryNet
 * Implements Fuzzy ART, HMM Emotion, Memory, and LLM cognitive algorithms
 */

import { logger } from '../utils/logger';
import { getRedis } from '../config/redis';
import { PrismaClient } from '@prisma/client';
import axios from 'axios';

import { transformerService } from './transformer.service';
import { graphService } from './graph.service';
import { config } from '../config';

const prisma = new PrismaClient();

// Cognitive Algorithm Configuration
const COGNITIVE_CONFIG = {
  art: {
    maps: {
      interaction: { n: 32, rho: 0.7, beta: 0.5 },
      emotional: { n: 3, rho: 0.8, beta: 0.6 },
      values: { n: 8, rho: 0.9, beta: 0.3 },
      behavioral: { n: 8, rho: 0.75, beta: 0.5 }
    }
  },
  hmm: {
    states: ["Calm", "Focused", "Social", "Serious", "Excited", "Fatigued"],
    defaultTransitions: [
      [0.50, 0.25, 0.10, 0.08, 0.05, 0.02],
      [0.15, 0.50, 0.05, 0.15, 0.10, 0.05],
      [0.15, 0.05, 0.50, 0.05, 0.20, 0.05],
      [0.10, 0.25, 0.05, 0.45, 0.05, 0.10],
      [0.10, 0.10, 0.30, 0.05, 0.35, 0.10],
      [0.25, 0.10, 0.05, 0.10, 0.05, 0.45]
    ],
    defaultMeans: [
      [0.60, 0.30, 0.55],
      [0.55, 0.55, 0.70],
      [0.75, 0.65, 0.60],
      [0.45, 0.50, 0.65],
      [0.80, 0.85, 0.70],
      [0.35, 0.20, 0.35]
    ]
  }
};

export interface CognitiveInput {
  userId: string;
  sessionId: string;
  message: string;
  context?: any;
}

export interface CognitiveOutput {
  response: string;
  confidence: number;
  analysis: any;
  state: {
    lastInput: string;
    lastResponse: string;
    confidence: number;
    context?: any;
    emotion?: string;
    personality?: string;
  };
  timestamp: string;
}

export class CognitiveService {
  private redis = getRedis();
  private prisma = prisma;
  private transformerService = transformerService;
  private graphService = graphService;

  /**
   * Process cognitive input and return AI-enhanced response
   */
  async process(input: CognitiveInput): Promise<CognitiveOutput> {
    try {
      // Get user context from database
      const user = await this.prisma.user.findUnique({
        where: { id: input.userId },
        include: {
          episodes: {
            where: { type: 'episodic' },
            orderBy: { createdAt: 'desc' },
            take: 10
          }
        }
      });

      if (!user) {
        throw new Error('User not found');
      }

      // Get current cognitive state from Redis
      const cognitiveState = await this.redis.get(`cognitive:${input.userId}`);
      const emotionState = await this.redis.get(`emotion:${input.userId}`);

      // Analyze message using transformer service
      const analysis = await this.transformerService.analyzeText(input.message);
      
      // Generate response using transformer service
      const response = await this.transformerService.generateText({
        prompt: input.message,
        context: input.context,
        userHistory: user.episodes.map(e => e.content),
        sessionId: input.sessionId
      });

      // Process Emotion (External)
      const emotion = await this.processEmotion(input.message, { userId: input.userId });
      
      // Process Personality (External)
      const personality = await this.processARTMap('interaction', this.extractFeatures(input.message), COGNITIVE_CONFIG.art.maps.interaction, input.userId);

      // Update cognitive state
      await this.storeCognitiveState(input.userId, {
        lastInput: input.message,
        lastResponse: response.text,
        confidence: response.confidence,
        emotion: emotion.state,
        personality: personality.action,
        context: input.context
      });

      // Store episode in database
      await this.storeEpisode(input.userId, input.sessionId, 'episodic', input.message, {
        response: response.text,
        analysis,
        confidence: response.confidence,
        emotion: emotion.state,
        personality: personality.action
      });

      return {
        response: response.text,
        confidence: response.confidence,
        analysis,
        state: {
          lastInput: input.message,
          lastResponse: response.text,
          confidence: response.confidence,
          context: input.context,
          emotion: emotion.state
        },
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      logger.error('Cognitive processing error:', error);
      throw error;
    }
  }

  /**
   * Analyze user behavior patterns
   */
  async analyzeUserBehavior(userId: string): Promise<any> {
    try {
      const episodes = await this.prisma.episode.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 100
      });

      const patterns = await this.graphService.analyzeUserBehavior(userId);
      
      return {
        userId,
        patterns,
        recentActivity: episodes.slice(0, 10),
        insights: await this.generateBehavioralInsights(episodes)
      };
    } catch (error) {
      logger.error('Error analyzing user behavior:', error);
      throw error;
    }
  }

  /**
   * Generate system-wide insights
   */
  async generateSystemInsights(): Promise<any> {
    try {
      const totalUsers = await this.prisma.user.count();
      const totalEpisodes = await this.prisma.episode.count();
      const recentActivity = await this.prisma.episode.findMany({
        orderBy: { createdAt: 'desc' },
        take: 100
      });

      const insights = await this.graphService.analyzeSystemPatterns();
      
      return {
        systemHealth: 'optimal',
        totalUsers,
        totalEpisodes,
        recentActivity,
        insights,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error generating system insights:', error);
      throw error;
    }
  }

  /**
   * Analyze support ticket using AI
   */
  async analyzeSupportTicket(ticketId: string): Promise<any> {
    try {
      // This would integrate with your support ticket system
      // For now, return a mock analysis
      return {
        ticketId,
        analysis: {
          category: 'technical',
          urgency: 'medium',
          suggestedResolution: 'Check network connectivity and restart service',
          confidence: 0.85
        },
        recommendations: [
          'Verify VPN connection status',
          'Check server logs for errors',
          'Restart the affected service'
        ],
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error analyzing support ticket:', error);
      throw error;
    }
  }

  /**
   * Generate personalized recommendations
   */
  async generatePersonalizedRecommendations(userId: string): Promise<any> {
    try {
      const userBehavior = await this.analyzeUserBehavior(userId);
      const patterns = userBehavior.patterns;
      
      const recommendations = await this.graphService.generateRecommendations(userId, patterns);
      
      return {
        userId,
        recommendations,
        basedOn: patterns,
        confidence: 0.9,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error generating recommendations:', error);
      throw error;
    }
  }

  /**
   * Detect anomalies in system data
   */
  async detectAnomalies(data: any): Promise<any> {
    try {
      const anomalies = await this.graphService.detectAnomalies(data);
      
      return {
        anomalies,
        count: anomalies.length,
        severity: anomalies.length > 10 ? 'high' : anomalies.length > 5 ? 'medium' : 'low',
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error detecting anomalies:', error);
      throw error;
    }
  }

  /**
   * Optimize server allocation based on current usage
   */
  async optimizeServerAllocation(currentAllocation: any): Promise<any> {
    try {
      const optimization = await this.graphService.optimizeServerAllocation(currentAllocation);
      
      return {
        optimization,
        savings: optimization.estimatedSavings,
        efficiency: optimization.efficiencyImprovement,
        recommendations: optimization.recommendations,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error optimizing server allocation:', error);
      throw error;
    }
  }

  /**
   * Get available AI models from OpenRouter
   */
  async getAvailableModels(): Promise<any> {
    try {
      // This would integrate with OpenRouter API
      // For now, return mock available models
      return {
        models: [
          { id: 'gpt-4', name: 'GPT-4', cost: '$0.03/1K tokens', capabilities: ['text', 'chat'] },
          { id: 'claude-3', name: 'Claude 3', cost: '$0.015/1K tokens', capabilities: ['text', 'chat'] },
          { id: 'llama-2', name: 'Llama 2', cost: '$0.001/1K tokens', capabilities: ['text'] },
          { id: 'mistral', name: 'Mistral', cost: '$0.002/1K tokens', capabilities: ['text'] }
        ],
        freeModels: [
          { id: 'llama-2', name: 'Llama 2', cost: 'Free', capabilities: ['text'] },
          { id: 'mistral', name: 'Mistral', cost: 'Free', capabilities: ['text'] }
        ],
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error getting available models:', error);
      throw error;
    }
  }

  /**
   * Chat with AI using OpenRouter models
   */
  async chatWithAI(messages: any[], model?: string, temperature?: number): Promise<any> {
    try {
      const response = await this.transformerService.generateText({
        prompt: messages[messages.length - 1].content,
        context: messages.slice(0, -1),
        model: model || 'llama-2',
        temperature: temperature || 0.7
      });

      return {
        response: response.text,
        model: model || 'llama-2',
        tokensUsed: response.tokensUsed,
        confidence: response.confidence,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error in AI chat:', error);
      throw error;
    }
  }

  /**
   * Generate behavioral insights from user episodes
   */
  private async generateBehavioralInsights(episodes: any[]): Promise<any> {
    try {
      const insights = [];
      
      // Analyze patterns in user behavior
      const messageTypes = episodes.reduce((acc, episode) => {
        acc[episode.type] = (acc[episode.type] || 0) + 1;
        return acc;
      }, {});

      insights.push({
        type: 'message_patterns',
        data: messageTypes,
        description: 'User message type distribution'
      });

      // Analyze time patterns
      const hourlyActivity = episodes.reduce((acc, episode) => {
        const hour = new Date(episode.createdAt).getHours();
        acc[hour] = (acc[hour] || 0) + 1;
        return acc;
      }, {});

      insights.push({
        type: 'time_patterns',
        data: hourlyActivity,
        description: 'User activity by hour of day'
      });

      return insights;
    } catch (error) {
      logger.error('Error generating behavioral insights:', error);
      return [];
    }
  }

  /**
   * HMM Emotion Processing
   */
  private async processEmotion(message: string, context: any): Promise<any> {
    try {
      // Extract VAD (Valence, Arousal, Dominance) from message
      const vad = this.extractVAD(message);
      
      // Call external HMM Emotion service
      const response = await axios.post(`${config.cognitive.hmmUrl}/observe`, {
        vad: vad
      }, {
        headers: { 'X-API-Key': config.cognitive.apiKey },
        timeout: 5000
      });

      const data = response.data;

      return {
        state: data.final_state || "Calm",
        confidence: data.hmm?.confidence || 0.8,
        signal: vad,
        history: data.hmm?.history?.slice(-10) || []
      };

    } catch (error: any) {
      logger.error('Emotion processing error (external):', error.message);
      return this.getDefaultEmotion();
    }
  }

  /**
   * Memory Processing
   */
  private async processMemory(input: CognitiveInput, context: any): Promise<any> {
    try {
      // Store new episode
      await this.storeEpisode(input.userId, input.sessionId, 'episodic', input.message);
      
      // Retrieve relevant memories
      const memories = await this.retrieveMemories(input.userId, input.message);
      
      return {
        stored: true,
        relevantMemories: memories,
        summary: this.summarizeMemories(memories)
      };

    } catch (error) {
      logger.error('Memory processing error:', error);
      return { stored: false, relevantMemories: [], summary: '' };
    }
  }

  /**
   * LLM Processing
   */
  private async processLLM(
    input: CognitiveInput, 
    emotion: any, 
    personality: any, 
    memory: any
  ): Promise<any> {
    try {
      // Build prompt with cognitive context
      const prompt = this.buildLLMPrompt(input, emotion, personality, memory);
      
      // Call LLM service
      const response = await this.callLLM(prompt);
      
      // Parse structured response
      return this.parseLLMResponse(response);

    } catch (error) {
      logger.error('LLM processing error:', error);
      return this.getDefaultLLMResponse();
    }
  }

  // Helper methods

  private extractFeatures(message: string): number[] {
    // Simple feature extraction - could be enhanced with ML models
    const words = message.toLowerCase().split(/\s+/);
    const features = new Array(32).fill(0);
    
    // Basic sentiment and content features
    const positiveWords = ['good', 'great', 'excellent', 'amazing', 'love', 'like'];
    const negativeWords = ['bad', 'terrible', 'hate', 'dislike', 'awful', 'horrible'];
    const technicalWords = ['vpn', 'internet', 'connection', 'speed', 'data', 'plan'];
    
    features[0] = positiveWords.some(word => words.includes(word)) ? 1 : 0;
    features[1] = negativeWords.some(word => words.includes(word)) ? 1 : 0;
    features[2] = technicalWords.some(word => words.includes(word)) ? 1 : 0;
    features[3] = message.length / 100; // Normalized length
    features[4] = words.length / 20; // Word count normalized
    
    return features;
  }

  private extractVAD(message: string): number[] {
    // Simple VAD extraction - could be enhanced with emotion detection models
    const valence = this.calculateValence(message);
    const arousal = this.calculateArousal(message);
    const dominance = this.calculateDominance(message);
    
    return [valence, arousal, dominance];
  }

  private calculateValence(message: string): number {
    const positive = ['happy', 'good', 'great', 'excellent', 'love', 'like', 'amazing'];
    const negative = ['sad', 'bad', 'terrible', 'hate', 'dislike', 'awful', 'angry'];
    
    const words = message.toLowerCase().split(/\s+/);
    const posCount = positive.filter(word => words.includes(word)).length;
    const negCount = negative.filter(word => words.includes(word)).length;
    
    return Math.max(0, Math.min(1, 0.5 + (posCount - negCount) * 0.1));
  }

  private calculateArousal(message: string): number {
    const excited = ['excited', 'amazing', 'incredible', 'wow', 'awesome', 'fantastic'];
    const calm = ['calm', 'relaxed', 'peaceful', 'quiet', 'serene', 'tranquil'];
    
    const words = message.toLowerCase().split(/\s+/);
    const excCount = excited.filter(word => words.includes(word)).length;
    const calmCount = calm.filter(word => words.includes(word)).length;
    
    return Math.max(0, Math.min(1, 0.5 + (excCount - calmCount) * 0.1));
  }

  private calculateDominance(message: string): number {
    const dominant = ['need', 'want', 'must', 'should', 'require', 'demand'];
    const submissive = ['please', 'could', 'would', 'might', 'maybe', 'possibly'];
    
    const words = message.toLowerCase().split(/\s+/);
    const domCount = dominant.filter(word => words.includes(word)).length;
    const subCount = submissive.filter(word => words.includes(word)).length;
    
    return Math.max(0, Math.min(1, 0.5 + (domCount - subCount) * 0.1));
  }

  private async processARTMap(mapName: string, features: number[], artConfig: any, userId: string): Promise<{ action: string; clusterId: number; prototype: number[] }> {
    try {
      // Call external ART Personality service
      const response = await axios.post(`${config.cognitive.artUrl}/learn`, {
        inputs: { [mapName]: features }
      }, {
        headers: { 'X-API-Key': config.cognitive.apiKey },
        timeout: 5000
      });

      const data = response.data;
      const mapResult = data[mapName] || {};

      return {
        action: mapResult.action || 'updated',
        clusterId: mapResult.cluster_id || 0,
        prototype: mapResult.prototype || features
      };

    } catch (error: any) {
      logger.error(`ART processing error for ${mapName} (external):`, error.message);
      return {
        action: 'error',
        clusterId: -1,
        prototype: features
      };
    }
  }

  private findBestMatch(features: number[], weights: number[][]): any {
    let bestScore = 0;
    let bestId = 0;
    
    for (let i = 0; i < weights.length; i++) {
      const score = this.calculateMatchScore(features, weights[i]);
      if (score > bestScore) {
        bestScore = score;
        bestId = i;
      }
    }
    
    return { id: bestId, score: bestScore };
  }

  private calculateMatchScore(a: number[], b: number[]): number {
    let score = 0;
    const n = Math.min(a.length, b.length);
    
    for (let i = 0; i < n; i++) {
      score += Math.min(a[i], b[i]);
    }
    
    return score / n;
  }

  private updateWeights(oldWeights: number[], newFeatures: number[], beta: number): number[] {
    const result: number[] = [];
    const n = Math.min(oldWeights.length, newFeatures.length);
    
    for (let i = 0; i < n; i++) {
      result[i] = beta * Math.min(oldWeights[i], newFeatures[i]) + (1 - beta) * oldWeights[i];
    }
    
    return result;
  }

  private fusePersonalityResults(results: any): any {
    // Simple fusion of personality results
    const prototypes: any = {};
    const maturities: any = {};
    let totalMaturity = 0;
    let mapCount = 0;
    const nClusters: any = {};

    for (const [mapName, item] of Object.entries(results)) {
      const result = item as any;
      if (result.prototype) {
        prototypes[mapName] = result.prototype;
      }
      if (result.maturity) {
        maturities[mapName] = result.maturity;
        totalMaturity += result.maturity;
        mapCount++;
      }
      nClusters[mapName] = result.nClusters || 1;
    }

    return {
      prototypes,
      maturities,
      avgMaturity: mapCount > 0 ? totalMaturity / mapCount : 0.5,
      nClusters
    };
  }

  private async getCurrentEmotionState(userId: string): Promise<any> {
    const key = `emotion:${userId}`;
    const state = await this.redis.get(key);
    
    if (state) {
      return JSON.parse(state);
    }
    
    return {
      currentState: 0, // Calm
      history: [0],
      transitions: COGNITIVE_CONFIG.hmm.defaultTransitions
    };
  }

  private updateHMM(currentState: any, observation: number[]): any {
    // Simplified HMM update
    const transitions = currentState.transitions;
    const current = currentState.currentState;
    
    // Find most likely next state
    let bestState = current;
    let bestScore = 0;
    
    for (let i = 0; i < transitions.length; i++) {
      const score = transitions[current][i] * this.emissionProbability(observation, i);
      if (score > bestScore) {
        bestScore = score;
        bestState = i;
      }
    }
    
    // Update transition probabilities (learning)
    transitions[current][bestState] += 0.03;
    const rowSum = (transitions[current] as number[]).reduce((a: number, b: number) => a + b, 0);
    transitions[current] = (transitions[current] as number[]).map((p: number) => p / rowSum);
    
    currentState.currentState = bestState;
    currentState.history.push(bestState);
    
    return currentState;
  }

  private emissionProbability(observation: number[], state: number): number {
    const means = COGNITIVE_CONFIG.hmm.defaultMeans[state];
    let prob = 1;
    
    for (let i = 0; i < observation.length; i++) {
      const diff = observation[i] - means[i];
      prob *= Math.exp(-diff * diff / 2) / Math.sqrt(2 * Math.PI);
    }
    
    return prob;
  }

  private async updateEmotionState(userId: string, newState: any): Promise<void> {
    const key = `emotion:${userId}`;
    await this.redis.set(key, JSON.stringify(newState));
  }

  private async storeEpisode(
    userId: string,
    sessionId: string,
    type: string,
    content: string,
    metadata?: any
  ): Promise<void> {
    await prisma.episode.create({
      data: {
        userId,
        sessionId,
        content,
        type,
        metadata: metadata ? JSON.stringify(metadata) : undefined,
        importance: 0.5,
        createdAt: new Date()
      }
    });
  }

  private async retrieveMemories(userId: string, query: string): Promise<any[]> {
    // Simple memory retrieval - could be enhanced with vector search
    const memories = await prisma.episode.findMany({
      where: {
        userId,
        content: {
          contains: query.split(' ')[0] // Simple keyword matching
        }
      },
      orderBy: { createdAt: 'desc' },
      take: 5
    });
    
    return memories;
  }

  private summarizeMemories(memories: any[]): string {
    if (memories.length === 0) return '';
    
    const content = memories.map(m => m.content).join(' ');
    return content.substring(0, 200) + (content.length > 200 ? '...' : '');
  }

  private buildLLMPrompt(input: CognitiveInput, emotion: any, personality: any, memory: any): string {
    return `
User: ${input.message}
Context: ${JSON.stringify(input.context)}
Emotion State: ${emotion.state} (confidence: ${emotion.confidence})
Personality Maturity: ${personality.avgMaturity}
Recent Memories: ${memory.summary}

Please provide a helpful response considering the user's emotional state and personality.
`;
  }

  private async callLLM(prompt: string): Promise<string> {
    // Call external LLM service or use local model
    // For now, return a mock response
    return `I understand you're feeling ${prompt.includes('happy') ? 'positive' : 'neutral'}. 
Let me help you with your VPN needs. Based on your personality profile, I recommend...`;
  }

  private parseLLMResponse(response: string): any {
    // Parse the LLM response into structured format
    return {
      response,
      reasoning: "Generated based on cognitive context",
      plan: ["Analyze user needs", "Provide recommendation", "Follow up"],
      emotionSignal: [0.5, 0.5, 0.5],
      behaviorVector: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
      stateUpdate: {
        mood: "neutral",
        confidence: 0.8,
        topic: "vpn_support"
      }
    };
  }

  private async getUserContext(userId: string, sessionId: string): Promise<any> {
    return {
      userId,
      sessionId,
      lastInteraction: await this.getLastInteraction(userId),
      preferences: await this.getUserPreferences(userId)
    };
  }

  private async getLastInteraction(userId: string): Promise<Date | null> {
    const last = await prisma.episode.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' }
    });
    return last?.createdAt || null;
  }

  private async getUserPreferences(userId: string): Promise<any> {
    // Could fetch from user preferences table
    return {};
  }

  private async storeCognitiveState(userId: string, state: any): Promise<void> {
    const key = `cognitive:${userId}`;
    await this.redis.set(key, JSON.stringify(state), 'EX', 3600); // 1 hour expiry
  }

  private getDefaultEmotion(): any {
    return {
      state: "Calm",
      confidence: 0.5,
      signal: [0.5, 0.5, 0.5],
      history: ["Calm"]
    };
  }

  private getDefaultLLMResponse(): any {
    return {
      response: "I'm here to help you with your VPN needs.",
      reasoning: "Default response generated",
      plan: ["Gather user requirements", "Provide plan options"],
      emotionSignal: [0.5, 0.5, 0.5],
      behaviorVector: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
      stateUpdate: {
        mood: "neutral",
        confidence: 0.5,
        topic: "general"
      }
    };
  }
}

// Export singleton instance
export const cognitiveService = new CognitiveService();
