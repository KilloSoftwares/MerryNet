import { Router } from 'express';
import { chatbotController } from '../controllers/chatbot.controller';

const router = Router();

/**
 * @route   POST /api/chatbot/message
 * @desc    Process a chat message with intelligent algorithms
 * @access  Public (can be protected with auth middleware)
 * @body    { message: string, conversationHistory?: ChatMessage[], userId?: string }
 */
router.post('/message', (req, res) => chatbotController.processMessage(req, res));

/**
 * @route   GET /api/chatbot/network-status
 * @desc    Get current network monitoring status
 * @access  Public
 */
router.get('/network-status', (req, res) => chatbotController.getNetworkStatus(req, res));

/**
 * @route   GET /api/chatbot/satisfaction-status
 * @desc    Get current user satisfaction metrics
 * @access  Public
 */
router.get('/satisfaction-status', (req, res) => chatbotController.getSatisfactionStatus(req, res));

/**
 * @route   POST /api/chatbot/feedback
 * @desc    Submit user feedback for satisfaction tracking
 * @access  Public (can be protected with auth middleware)
 * @body    { score: number (1-5), comment?: string }
 */
router.post('/feedback', (req, res) => chatbotController.submitFeedback(req, res));

/**
 * @route   POST /api/chatbot/analyze
 * @desc    Analyze text with intelligent algorithms (for testing/debugging)
 * @access  Public
 * @body    { text: string }
 */
router.post('/analyze', (req, res) => chatbotController.analyzeText(req, res));

export default router;