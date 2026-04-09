/**
 * Intelligent Algorithms Service for MerryNet
 * Implements animal-inspired AI algorithms for smarter chatbot responses
 * This service provides the core intelligent processing capabilities
 */

export interface SentimentResult {
  sentiment: number;
  positivity: number;
  negativity: number;
  urgency: number;
  emotionalTone: 'positive' | 'negative' | 'neutral';
}

export interface TopicResult {
  topic: string;
  score: number;
}

export interface ResponseStrategy {
  type: string;
  weight: number;
}

export interface NetworkStatus {
  status: 'healthy' | 'degraded' | 'poor' | 'offline';
  quality: number;
  avgLatency: number;
  successRate: number;
  totalCalls: number;
  totalErrors: number;
}

export interface SatisfactionStatus {
  satisfaction: number;
  trend: 'improving' | 'declining' | 'stable';
  totalInteractions: number;
  lastFeedback: { score: number; comment: string; timestamp: string } | null;
  feedbackCount: number;
}

export interface IntelligenceAnalysis {
  sentiment: SentimentResult;
  topics: TopicResult[];
  uncertainty: number;
  strategies: ResponseStrategy[];
  timestamp: string;
}

const POSITIVE_WORDS = new Set([
  'great', 'excellent', 'wonderful', 'amazing', 'love', 'happy', 'excited',
  'fantastic', 'brilliant', 'perfect', 'awesome', 'good', 'nice', 'helpful',
  'thank', 'thanks', 'please', 'beautiful', 'joy', 'delighted'
]);

const NEGATIVE_WORDS = new Set([
  'terrible', 'awful', 'horrible', 'hate', 'angry', 'sad', 'frustrated',
  'annoyed', 'disappointed', 'worried', 'confused', 'stupid', 'bad', 'wrong',
  'fail', 'error', 'problem', 'issue', 'difficult', 'hard'
]);

const URGENT_WORDS = new Set([
  'now', 'urgent', 'emergency', 'immediately', 'asap', 'help', 'quick',
  'fast', 'critical', 'important'
]);

const VAGUE_WORDS = new Set([
  'something', 'anything', 'maybe', 'perhaps', 'possibly', 'might',
  'could', 'would', 'should', 'thing', 'stuff'
]);

const UNCERTAINTY_PATTERNS = [
  /what\s+is\s+the\s+(best|correct|right|exact|true)/i,
  /how\s+do\s+i\s+know/i,
  /can\s+you\s+(prove|confirm|verify|guarantee)/i,
  /is\s+it\s+true\s+that/i,
  /i\s+(don'?t\s+)?(understand|know|get|believe)\s+(that|if|whether|why)/i,
  /explain\s+why/i,
  /what\s+(happens|if|about)\s+when/i,
  /\s+[a-z]+\s*\/\s*[a-z]+\s/i,
  /should\s+i\s+/i,
  /which\s+one\s+should/i,
];

const TOPIC_CATEGORIES: Record<string, Set<string>> = {
  technology: new Set([
    'code', 'program', 'software', 'computer', 'algorithm', 'data', 'api',
    'database', 'server', 'cloud', 'ai', 'machine', 'learning', 'neural',
    'network', 'python', 'javascript', 'html', 'css', 'react', 'node',
    'docker', 'kubernetes'
  ]),
  science: new Set([
    'physics', 'chemistry', 'biology', 'experiment', 'research', 'theory',
    'hypothesis', 'scientific', 'discovery', 'evolution', 'genetics',
    'molecule', 'atom', 'cell', 'organism'
  ]),
  math: new Set([
    'calculate', 'equation', 'formula', 'algebra', 'calculus', 'geometry',
    'statistic', 'probability', 'number', 'solve', 'theorem', 'proof',
    'integral', 'derivative', 'matrix'
  ]),
  creative: new Set([
    'write', 'story', 'poem', 'creative', 'art', 'design', 'music', 'draw',
    'paint', 'imagine', 'fiction', 'character', 'plot', 'narrative', 'metaphor'
  ]),
  emotional: new Set([
    'feel', 'emotion', 'happy', 'sad', 'angry', 'worried', 'anxious',
    'stressed', 'love', 'hate', 'fear', 'hope', 'dream', 'relationship', 'friend'
  ]),
  practical: new Set([
    'how', 'what', 'when', 'where', 'steps', 'guide', 'tutorial',
    'instruction', 'process', 'method', 'technique', 'strategy', 'plan',
    'organize', 'manage'
  ]),
  philosophical: new Set([
    'meaning', 'purpose', 'existence', 'consciousness', 'reality', 'truth',
    'knowledge', 'ethics', 'morality', 'philosophy', 'mind', 'soul', 'free',
    'will', 'nature'
  ]),
  business: new Set([
    'money', 'business', 'company', 'market', 'investment', 'profit',
    'strategy', 'customer', 'product', 'sales', 'marketing', 'finance',
    'economy', 'startup', 'entrepreneur'
  ]),
  networking: new Set([
    'vpn', 'internet', 'connection', 'bandwidth', 'speed', 'latency',
    'ping', 'packet', 'route', 'proxy', 'firewall', 'dns', 'ip',
    'download', 'upload', 'mbps', 'gbps', 'data', 'traffic', 'usage'
  ]),
};

const CONNECTORS = [
  'therefore', 'however', 'because', 'thus', 'consequently', 'moreover',
  'furthermore', 'in addition', 'on the other hand', 'as a result',
  'for example', 'in conclusion', 'specifically', 'particularly'
];

const CONFIDENCE_WORDS = [
  'definitely', 'certainly', 'clearly', 'obviously', 'undoubtedly',
  'absolutely', 'precisely', 'exactly'
];

const UNCERTAINTY_LANGUAGE = [
  'maybe', 'perhaps', 'possibly', 'might', 'could', 'seems', 'appears',
  'probably', 'likely', 'i think', 'i believe', 'in my opinion'
];

const ENGAGEMENT_WORDS = [
  'great', 'thanks', 'perfect', 'exactly', 'helpful', 'awesome', 'love',
  'amazing', 'brilliant'
];

const DISENGAGEMENT_WORDS = [
  'wrong', 'not helpful', 'confusing', 'unclear', 'bad', 'terrible', 'useless'
];

/**
 * ALGORITHM 1: Sentiment & Emotional Intelligence (Elephant Empathy)
 */
export function analyzeSentiment(text: string): SentimentResult {
  const words = text.toLowerCase().split(/\s+/);
  let posCount = 0, negCount = 0, urgCount = 0;

  for (const w of words) {
    const clean = w.replace(/[^a-z]/g, '');
    if (POSITIVE_WORDS.has(clean)) posCount++;
    if (NEGATIVE_WORDS.has(clean)) negCount++;
    if (URGENT_WORDS.has(clean)) urgCount++;
  }

  const total = words.length || 1;
  const sentiment = (posCount - negCount) / total;
  const positivity = posCount / total;
  const negativity = negCount / total;
  const urgency = Math.min(urgCount / 3, 1);
  const emotionalTone = posCount > negCount ? 'positive' : negCount > posCount ? 'negative' : 'neutral';

  return { sentiment, positivity, negativity, urgency, emotionalTone };
}

/**
 * ALGORITHM 2: Uncertainty Estimation (Crow Metacognition)
 */
export function estimateUncertainty(input: string): number {
  let uncertaintyScore = 0;
  for (const pattern of UNCERTAINTY_PATTERNS) {
    if (pattern.test(input)) uncertaintyScore += 0.15;
  }

  const words = input.toLowerCase().split(/\s+/);
  const vagueCount = words.filter(w => VAGUE_WORDS.has(w.replace(/[^a-z]/g, ''))).length;
  uncertaintyScore += Math.min(vagueCount * 0.1, 0.4);

  if (/[\w]+\s*[(){}\[\]<>]/.test(input)) {
    uncertaintyScore += 0.1;
  }

  return Math.min(uncertaintyScore, 1);
}

/**
 * ALGORITHM 3: Topic Modeling via Keyword Extraction (Ant Colony)
 */
export function extractTopics(text: string): TopicResult[] {
  const words = text.toLowerCase().split(/\s+/);
  const topicScores: Record<string, number> = {};

  for (const [topic, keywords] of Object.entries(TOPIC_CATEGORIES)) {
    let score = 0;
    for (const w of words) {
      const clean = w.replace(/[^a-z]/g, '');
      if (keywords.has(clean)) {
        score += 1;
      } else if ([...keywords].some(k => k.includes(clean) && clean.length > 2)) {
        score += 0.3;
      }
    }
    if (score > 0) topicScores[topic] = score;
  }

  const total = Object.values(topicScores).reduce((a, b) => a + b, 0) || 1;
  for (const k of Object.keys(topicScores)) {
    topicScores[k] /= total;
  }

  return Object.entries(topicScores)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([topic, score]) => ({ topic, score }));
}

/**
 * ALGORITHM 4: Response Quality Scoring (Wolf Pack Deliberation)
 */
export function scoreResponseQuality(response: string, input: string): number {
  let score = 0.5;

  const responseLen = response.length;
  const inputLen = input.length;
  const lenRatio = responseLen / Math.max(inputLen, 10);
  if (lenRatio >= 0.5 && lenRatio <= 5) score += 0.1;
  if (responseLen < 20) score -= 0.2;

  const inputWords = new Set(input.toLowerCase().split(/\s+/).map(w => w.replace(/[^a-z]/g, '')));
  const responseWords = response.toLowerCase().split(/\s+/).map(w => w.replace(/[^a-z]/g, ''));
  let overlap = 0;
  for (const w of responseWords) {
    if (inputWords.has(w) && w.length > 3) overlap++;
  }
  const relevanceRatio = (overlap / Math.max(responseWords.length, 1)) * 10;
  if (relevanceRatio > 0.3) score += 0.15;

  if (CONNECTORS.some(c => response.toLowerCase().includes(c))) score += 0.1;

  if (response.includes('\n\n') || response.includes('- ') || response.includes('1.') || response.includes('•')) {
    score += 0.05;
  }

  const confCount = CONFIDENCE_WORDS.filter(w => response.toLowerCase().includes(w)).length;
  const uncertCount = UNCERTAINTY_LANGUAGE.filter(w => response.toLowerCase().includes(w)).length;
  if (confCount > uncertCount) score += 0.05;
  if (uncertCount > confCount) score -= 0.05;

  return Math.max(0, Math.min(1, score));
}

/**
 * ALGORITHM 5: Adaptive Response Strategy (Chromatophore Adaptation)
 */
export function determineResponseStrategy(
  input: string,
  sentiment: SentimentResult,
  topics: TopicResult[],
  uncertainty: number
): ResponseStrategy[] {
  const strategies: ResponseStrategy[] = [];

  if (sentiment.emotionalTone === 'negative') {
    strategies.push({ type: 'empathetic', weight: 0.8 });
    strategies.push({ type: 'supportive', weight: 0.6 });
  } else if (sentiment.emotionalTone === 'positive') {
    strategies.push({ type: 'enthusiastic', weight: 0.6 });
    strategies.push({ type: 'encouraging', weight: 0.5 });
  }

  if (sentiment.urgency > 0.5) {
    strategies.push({ type: 'concise', weight: 0.9 });
    strategies.push({ type: 'actionable', weight: 0.7 });
  }

  if (uncertainty > 0.5) {
    strategies.push({ type: 'clarifying', weight: uncertainty });
    strategies.push({ type: 'educational', weight: 0.6 });
  }

  for (const t of topics) {
    if (t.topic === 'technology' || t.topic === 'math') {
      strategies.push({ type: 'technical', weight: t.score * 2 });
    } else if (t.topic === 'creative') {
      strategies.push({ type: 'creative', weight: t.score * 2 });
    } else if (t.topic === 'philosophical') {
      strategies.push({ type: 'reflective', weight: t.score * 2 });
    } else if (t.topic === 'practical') {
      strategies.push({ type: 'instructional', weight: t.score * 2 });
    } else if (t.topic === 'networking') {
      strategies.push({ type: 'technical', weight: t.score * 2 });
    }
  }

  if (strategies.length === 0) {
    strategies.push({ type: 'informative', weight: 0.5 });
  }

  return strategies.sort((a, b) => b.weight - a.weight).slice(0, 3);
}

/**
 * ALGORITHM 6: Semantic Similarity (Bat Echolocation)
 */
export function semanticSimilarity(text1: string, text2: string): number {
  const words1 = new Set(text1.toLowerCase().split(/\s+/).map(w => w.replace(/[^a-z]/g, '')).filter(w => w.length > 2));
  const words2 = new Set(text2.toLowerCase().split(/\s+/).map(w => w.replace(/[^a-z]/g, '')).filter(w => w.length > 2));

  const intersection = [...words1].filter(w => words2.has(w)).length;
  const union = new Set([...words1, ...words2]).size;
  return union > 0 ? intersection / union : 0;
}

/**
 * Full Intelligence Analysis - Combines all algorithms
 */
export function analyzeInput(text: string): IntelligenceAnalysis {
  const sentiment = analyzeSentiment(text);
  const topics = extractTopics(text);
  const uncertainty = estimateUncertainty(text);
  const strategies = determineResponseStrategy(text, sentiment, topics, uncertainty);

  return {
    sentiment,
    topics,
    uncertainty,
    strategies,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Network Health Monitor (Honeybee Waggle Dance Network)
 */
export class NetworkMonitor {
  private latency: number[] = [];
  private successRate: number[] = [];
  private status: NetworkStatus['status'] = 'healthy';
  private apiCalls = 0;
  private apiErrors = 0;
  private avgLatency = 0;
  private connectionQuality = 1.0;

  recordLatency(ms: number) {
    this.latency.push(ms);
    if (this.latency.length > 50) this.latency.shift();
    this.avgLatency = this.latency.reduce((a, b) => a + b, 0) / this.latency.length;
  }

  recordSuccess() {
    this.apiCalls++;
    this.successRate.push(1);
    if (this.successRate.length > 20) this.successRate.shift();
    this.updateStatus();
  }

  recordError() {
    this.apiCalls++;
    this.apiErrors++;
    this.successRate.push(0);
    if (this.successRate.length > 20) this.successRate.shift();
    this.updateStatus();
  }

  private updateStatus() {
    const recentCount = Math.min(this.successRate.length, 10);
    const recentSuccess = this.successRate.length > 0
      ? this.successRate.slice(-recentCount).reduce((a, b) => a + b, 0) / recentCount
      : 1;
    const latencyHealth = this.avgLatency < 1000 ? 1 : this.avgLatency < 3000 ? 0.7 : this.avgLatency < 5000 ? 0.4 : 0.2;
    this.connectionQuality = (recentSuccess * 0.6 + latencyHealth * 0.4);

    if (this.connectionQuality > 0.8) this.status = 'healthy';
    else if (this.connectionQuality > 0.5) this.status = 'degraded';
    else if (this.connectionQuality > 0.2) this.status = 'poor';
    else this.status = 'offline';
  }

  getStatus(): NetworkStatus {
    const recentCount = Math.min(this.successRate.length, 10);
    const recentSuccess = this.successRate.length > 0
      ? this.successRate.slice(-recentCount).reduce((a, b) => a + b, 0) / recentCount
      : 1;
    return {
      status: this.status,
      quality: this.connectionQuality,
      avgLatency: Math.round(this.avgLatency),
      successRate: Math.round(recentSuccess * 100),
      totalCalls: this.apiCalls,
      totalErrors: this.apiErrors,
    };
  }

  reset() {
    this.latency = [];
    this.successRate = [];
    this.apiCalls = 0;
    this.apiErrors = 0;
    this.status = 'healthy';
    this.connectionQuality = 1.0;
  }
}

/**
 * User Satisfaction Tracker (Dolphin Social Bonding)
 */
export class SatisfactionTracker {
  private scores: number[] = [];
  private interactions: Array<{ timestamp: string; input: string; response: string; responseTime: number; quality: number; implicitScore: number }> = [];
  private overallSatisfaction = 0.7;
  private trend: SatisfactionStatus['trend'] = 'stable';
  private lastFeedback: { score: number; comment: string; timestamp: string } | null = null;
  private feedbackHistory: Array<{ score: number; comment: string; timestamp: string }> = [];

  recordInteraction(userInput: string, response: string, responseTime: number, quality: number): number {
    const implicitScore = this.calculateImplicitScore(userInput, response, responseTime, quality);

    this.interactions.push({
      timestamp: new Date().toISOString(),
      input: userInput,
      response,
      responseTime,
      quality,
      implicitScore,
    });
    if (this.interactions.length > 100) this.interactions.shift();

    this.scores.push(implicitScore);
    if (this.scores.length > 50) this.scores.shift();

    this.overallSatisfaction = this.scores.reduce((a, b) => a + b, 0) / this.scores.length;
    this.trend = this.calculateTrend();

    return implicitScore;
  }

  private calculateImplicitScore(input: string, response: string, responseTime: number, quality: number): number {
    let score = 0.7;

    score += quality * 0.2;

    if (responseTime > 10000) score -= 0.15;
    else if (responseTime > 5000) score -= 0.05;
    else if (responseTime < 2000) score += 0.05;

    const lenRatio = response.length / Math.max(input.length, 10);
    if (lenRatio >= 1 && lenRatio <= 4) score += 0.05;
    else if (lenRatio < 0.5 || lenRatio > 8) score -= 0.1;

    const inputLower = input.toLowerCase();
    if (ENGAGEMENT_WORDS.some(w => inputLower.includes(w))) score += 0.15;
    if (DISENGAGEMENT_WORDS.some(w => inputLower.includes(w))) score -= 0.2;

    return Math.max(0, Math.min(1, score));
  }

  private calculateTrend(): SatisfactionStatus['trend'] {
    if (this.scores.length < 5) return 'stable';

    const recent = this.scores.slice(-5);
    const older = this.scores.slice(-10, -5);

    const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
    const olderAvg = older.length > 0 ? older.reduce((a, b) => a + b, 0) / older.length : recentAvg;

    const diff = recentAvg - olderAvg;

    if (diff > 0.1) return 'improving';
    else if (diff < -0.1) return 'declining';
    else return 'stable';
  }

  explicitFeedback(score: number, comment: string) {
    this.lastFeedback = { score, comment, timestamp: new Date().toISOString() };
    this.feedbackHistory.push(this.lastFeedback);
    if (this.feedbackHistory.length > 20) this.feedbackHistory.shift();

    this.scores.push(score / 5);
    if (this.scores.length > 50) this.scores.shift();
    this.overallSatisfaction = this.scores.reduce((a, b) => a + b, 0) / this.scores.length;
    this.trend = this.calculateTrend();
  }

  getStatus(): SatisfactionStatus {
    return {
      satisfaction: Math.round(this.overallSatisfaction * 100),
      trend: this.trend,
      totalInteractions: this.interactions.length,
      lastFeedback: this.lastFeedback,
      feedbackCount: this.feedbackHistory.length,
    };
  }

  reset() {
    this.scores = [];
    this.interactions = [];
    this.overallSatisfaction = 0.7;
    this.trend = 'stable';
    this.lastFeedback = null;
    this.feedbackHistory = [];
  }
}

// Singleton instances for the service
const networkMonitor = new NetworkMonitor();
const satisfactionTracker = new SatisfactionTracker();

/**
 * Intelligent Algorithms Service - Main export
 * Provides all intelligent processing capabilities for the chatbot
 */
export const IntelligentAlgorithmsService = {
  analyzeSentiment,
  estimateUncertainty,
  extractTopics,
  scoreResponseQuality,
  determineResponseStrategy,
  semanticSimilarity,
  analyzeInput,
  getNetworkStatus: () => networkMonitor.getStatus(),
  getSatisfactionStatus: () => satisfactionTracker.getStatus(),
  recordNetworkLatency: (ms: number) => networkMonitor.recordLatency(ms),
  recordNetworkSuccess: () => networkMonitor.recordSuccess(),
  recordNetworkError: () => networkMonitor.recordError(),
  recordInteraction: (input: string, response: string, time: number, quality: number) =>
    satisfactionTracker.recordInteraction(input, response, time, quality),
  recordFeedback: (score: number, comment: string) =>
    satisfactionTracker.explicitFeedback(score, comment),
  resetNetworkMonitor: () => networkMonitor.reset(),
  resetSatisfactionTracker: () => satisfactionTracker.reset(),
};