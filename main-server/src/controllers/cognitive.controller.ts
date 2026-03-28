import { Request, Response } from 'express';
import { cognitiveService, CognitiveInput, CognitiveOutput } from '../services/cognitive.service';
import { logger } from '../utils/logger';
import { prisma } from '../config/database';
import { getRedis } from '../config/redis';

export class CognitiveController {
  /**
   * Process cognitive input and return AI-enhanced response
   */
  static async process(req: Request, res: Response): Promise<void> {
    try {
      const { message, context } = req.body;
      const userId = req.user!.id;
      const sessionId = req.headers['x-session-id'] as string || `session_${Date.now()}`;

      if (!message) {
        res.status(400).json({ error: 'Message is required' });
        return;
      }

      const input: CognitiveInput = {
        userId,
        sessionId,
        message,
        context
      };

      const result = await cognitiveService.process(input);

      res.json({
        success: true,
        data: result,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      logger.error('Cognitive processing error:', error);
      res.status(500).json({
        success: false,
        error: 'Cognitive processing failed',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  /**
   * Get current cognitive state for user
   */
  static async getState(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.user!.id;
      const redis = getRedis();
      
      const cognitiveState = await redis.get(`cognitive:${userId}`);
      const emotionState = await redis.get(`emotion:${userId}`);

      res.json({
        success: true,
        data: {
          cognitiveState: cognitiveState ? JSON.parse(cognitiveState) : null,
          emotionState: emotionState ? JSON.parse(emotionState) : null,
          lastUpdated: new Date().toISOString()
        }
      });

    } catch (error) {
      logger.error('Get cognitive state error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve cognitive state'
      });
    }
  }

  /**
   * Get user memories and episodes
   */
  static async getMemories(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.user!.id;
      const limit = parseInt(req.query.limit as string) || 10;
      const type = req.query.type as string || 'episodic';

      const memories = await prisma.episode.findMany({
        where: {
          userId,
          type
        },
        orderBy: { createdAt: 'desc' },
        take: limit
      });

      res.json({
        success: true,
        data: {
          memories,
          count: memories.length
        }
      });

    } catch (error) {
      logger.error('Get memories error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve memories'
      });
    }
  }

  /**
   * Provide feedback to improve cognitive system
   */
  static async provideFeedback(req: Request, res: Response): Promise<void> {
    try {
      const { rating, comment, sessionId } = req.body;
      const userId = req.user!.id;

      if (!rating || rating < 1 || rating > 5) {
        res.status(400).json({ error: 'Rating must be between 1 and 5' });
        return;
      }

      // Store feedback
      await prisma.episode.create({
        data: {
          userId,
          sessionId: sessionId || `session_${Date.now()}`,
          type: 'feedback',
          content: comment || '',
          metadata: { rating, type: 'cognitive_feedback' },
          importance: rating / 5,
          createdAt: new Date()
        }
      });

      res.json({
        success: true,
        message: 'Feedback received and stored for cognitive system improvement'
      });

    } catch (error) {
      logger.error('Provide feedback error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to store feedback'
      });
    }
  }

  /**
   * Get cognitive system statistics (admin only)
   */
  static async getStats(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.user!.id;
      
      // Check if user is admin (you might want to add proper admin role checking)
      const user = await prisma.user.findUnique({
        where: { id: userId }
      });

      if (!user || user.phone !== process.env.ADMIN_PHONE) {
        res.status(403).json({ error: 'Admin access required' });
        return;
      }

      const stats = {
        totalUsers: await prisma.user.count(),
        totalEpisodes: await prisma.episode.count(),
        totalMemories: await prisma.episode.count({
          where: { type: 'episodic' }
        }),
        totalFeedback: await prisma.episode.count({
          where: { type: 'feedback' }
        }),
        activeCognitiveStates: await CognitiveController.getActiveCognitiveStatesCount()
      };

      res.json({
        success: true,
        data: stats
      });

    } catch (error) {
      logger.error('Get stats error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve statistics'
      });
    }
  }

  /**
   * Reset cognitive state for user (admin only)
   */
  static async resetState(req: Request, res: Response): Promise<void> {
    try {
      const { userId: targetUserId } = req.body;
      const adminId = req.user!.id;

      // Check if user is admin
      const admin = await prisma.user.findUnique({
        where: { id: adminId }
      });

      if (!admin || admin.phone !== process.env.ADMIN_PHONE) {
        res.status(403).json({ error: 'Admin access required' });
        return;
      }

      if (!targetUserId) {
        res.status(400).json({ error: 'Target user ID is required' });
        return;
      }
      
      const redis = getRedis();
      
      // Clear cognitive states from Redis
      await redis.del(`cognitive:${targetUserId}`);
      await redis.del(`emotion:${targetUserId}`);
      await redis.del(`art:interaction:32`);
      await redis.del(`art:emotional:3`);
      await redis.del(`art:values:8`);
      await redis.del(`art:behavioral:8`);

      // Optionally clear database records (be careful with this)
      // await prisma.episode.deleteMany({ where: { userId: targetUserId } });

      res.json({
        success: true,
        message: `Cognitive state reset for user ${targetUserId}`
      });

    } catch (error) {
      logger.error('Reset state error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to reset cognitive state'
      });
    }
  }

  /**
   * Get user behavior analysis
   */
  static async getUserBehavior(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const user = req.user;

      // Check permissions - only admin can access other users' data
      if (!user) {
        res.status(401).json({ error: 'Authentication required' });
        return;
      }

      if (user.id !== userId && !user.isReseller) {
        res.status(403).json({ error: 'Access denied' });
        return;
      }

      const behavior = await cognitiveService.analyzeUserBehavior(userId);
      res.json(behavior);

    } catch (error) {
      logger.error('Error getting user behavior:', error);
      res.status(500).json({ error: 'Failed to analyze user behavior' });
    }
  }

  /**
   * Get system insights
   */
  static async getSystemInsights(req: Request, res: Response): Promise<void> {
    try {
      const insights = await cognitiveService.generateSystemInsights();
      res.json(insights);

    } catch (error) {
      logger.error('Error getting system insights:', error);
      res.status(500).json({ error: 'Failed to generate system insights' });
    }
  }

  /**
   * Analyze support ticket
   */
  static async analyzeSupportTicket(req: Request, res: Response): Promise<void> {
    try {
      const { ticketId } = req.params;
      const user = req.user;

      // Check permissions - only resellers can access support features
      if (!user || !user.isReseller) {
        res.status(403).json({ error: 'Access denied' });
        return;
      }

      const analysis = await cognitiveService.analyzeSupportTicket(ticketId);
      res.json(analysis);

    } catch (error) {
      logger.error('Error analyzing support ticket:', error);
      res.status(500).json({ error: 'Failed to analyze support ticket' });
    }
  }

  /**
   * Get personalized recommendations
   */
  static async getPersonalizedRecommendations(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const user = req.user;

      // Check permissions - only admin can access other users' data
      if (!user) {
        res.status(401).json({ error: 'Authentication required' });
        return;
      }

      if (user.id !== userId && !user.isReseller) {
        res.status(403).json({ error: 'Access denied' });
        return;
      }

      const recommendations = await cognitiveService.generatePersonalizedRecommendations(userId);
      res.json(recommendations);

    } catch (error) {
      logger.error('Error getting recommendations:', error);
      res.status(500).json({ error: 'Failed to generate recommendations' });
    }
  }

  /**
   * Detect anomalies
   */
  static async detectAnomalies(req: Request, res: Response): Promise<void> {
    try {
      const { data } = req.body;
      const user = req.user;

      // Check permissions - only resellers can access security features
      if (!user || !user.isReseller) {
        res.status(403).json({ error: 'Access denied' });
        return;
      }

      const anomalies = await cognitiveService.detectAnomalies(data);
      res.json(anomalies);

    } catch (error) {
      logger.error('Error detecting anomalies:', error);
      res.status(500).json({ error: 'Failed to detect anomalies' });
    }
  }

  /**
   * Optimize server allocation
   */
  static async optimizeServerAllocation(req: Request, res: Response): Promise<void> {
    try {
      const { currentAllocation } = req.body;
      const user = req.user;

      // Check permissions - only resellers can access server management
      if (!user || !user.isReseller) {
        res.status(403).json({ error: 'Access denied' });
        return;
      }

      const optimization = await cognitiveService.optimizeServerAllocation(currentAllocation);
      res.json(optimization);

    } catch (error) {
      logger.error('Error optimizing server allocation:', error);
      res.status(500).json({ error: 'Failed to optimize server allocation' });
    }
  }

  /**
   * Get available models
   */
  static async getAvailableModels(req: Request, res: Response): Promise<void> {
    try {
      const user = req.user;

      // Check permissions - only resellers can access model management
      if (!user || !user.isReseller) {
        res.status(403).json({ error: 'Access denied' });
        return;
      }

      const models = await cognitiveService.getAvailableModels();
      res.json(models);

    } catch (error) {
      logger.error('Error getting available models:', error);
      res.status(500).json({ error: 'Failed to get available models' });
    }
  }

  /**
   * Chat with AI
   */
  static async chatWithAI(req: Request, res: Response): Promise<void> {
    try {
      const { messages, model, temperature } = req.body;
      const user = req.user;

      // Validate input
      if (!Array.isArray(messages) || messages.length === 0) {
        res.status(400).json({ error: 'Invalid messages format' });
        return;
      }

      // Check permissions - only authenticated users can access AI chat
      if (!user) {
        res.status(401).json({ error: 'Authentication required' });
        return;
      }

      const response = await cognitiveService.chatWithAI(messages, model, temperature);
      res.json(response);

    } catch (error) {
      logger.error('Error in AI chat:', error);
      res.status(500).json({ error: 'Failed to process AI request' });
    }
  }

  private static async getActiveCognitiveStatesCount(): Promise<number> {
    const redis = getRedis();
    const keys = await redis.keys('cognitive:*');
    return keys.length;
  }
}

// Export singleton instance for backward compatibility
export const cognitiveController = new CognitiveController();
