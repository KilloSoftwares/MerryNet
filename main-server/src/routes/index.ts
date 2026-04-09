import { Router, Request, Response } from 'express';
import authRoutes from './auth.routes';
import subscriptionRoutes from './subscription.routes';
import paymentRoutes from './payment.routes';
import resellerRoutes from './reseller.routes';
import cognitiveRoutes from './cognitive.routes';
import chatbotRoutes from './chatbot.routes';

const router = Router();

// Health check
router.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    data: {
      status: 'healthy',
      service: 'maranet-api',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    },
  });
});

// API routes
router.use('/auth', authRoutes);
router.use('/payments', paymentRoutes);
router.use('/subscriptions', subscriptionRoutes);
router.use('/resellers', resellerRoutes);
router.use('/cognitive', cognitiveRoutes);
router.use('/chatbot', chatbotRoutes);

export default router;
