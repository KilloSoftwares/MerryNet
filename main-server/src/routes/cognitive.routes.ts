import { Router } from 'express';
import { CognitiveController } from '../controllers/cognitive.controller';
import { authenticate } from '../middleware/auth';
import { rateLimiter } from '../middleware/rateLimiter';

const router = Router();

// Enhanced routes with OpenRouter integration
router.get('/user-behavior/:userId', 
  authenticate, 
  rateLimiter(60), 
  CognitiveController.getUserBehavior
);

router.get('/system-insights',
  authenticate,
  rateLimiter(30),
  CognitiveController.getSystemInsights
);

router.post('/analyze-ticket/:ticketId',
  authenticate,
  rateLimiter(100),
  CognitiveController.analyzeSupportTicket
);

router.get('/recommendations/:userId',
  authenticate,
  rateLimiter(60),
  CognitiveController.getPersonalizedRecommendations
);

router.post('/detect-anomalies',
  authenticate,
  rateLimiter(50),
  CognitiveController.detectAnomalies
);

router.post('/optimize-allocation',
  authenticate,
  rateLimiter(30),
  CognitiveController.optimizeServerAllocation
);

router.get('/available-models',
  authenticate,
  rateLimiter(100),
  CognitiveController.getAvailableModels
);

router.post('/chat',
  authenticate,
  rateLimiter(200),
  CognitiveController.chatWithAI
);

// Legacy endpoints for backward compatibility
router.post('/process', authenticate, CognitiveController.process);
router.get('/state', authenticate, CognitiveController.getState);
router.get('/memories', authenticate, CognitiveController.getMemories);
router.post('/feedback', authenticate, CognitiveController.provideFeedback);

// Admin endpoints for cognitive system management
router.get('/admin/stats', authenticate, CognitiveController.getStats);
router.delete('/admin/reset', authenticate, CognitiveController.resetState);

export default router;
