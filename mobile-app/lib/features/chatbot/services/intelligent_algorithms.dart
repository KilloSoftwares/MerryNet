import 'dart:math';

/// Sentiment analysis result
class SentimentResult {
  final double sentiment;
  final double positivity;
  final double negativity;
  final double urgency;
  final String emotionalTone;

  SentimentResult({
    required this.sentiment,
    required this.positivity,
    required this.negativity,
    required this.urgency,
    required this.emotionalTone,
  });
}

/// Topic extraction result
class TopicResult {
  final String topic;
  final double score;

  TopicResult({required this.topic, required this.score});
}

/// Response strategy
class ResponseStrategy {
  final String type;
  final double weight;

  ResponseStrategy({required this.type, required this.weight});
}

/// Network monitoring status
class NetworkStatus {
  final String status;
  final double quality;
  final int avgLatency;
  final int successRate;
  final int totalCalls;
  final int totalErrors;

  NetworkStatus({
    required this.status,
    required this.quality,
    required this.avgLatency,
    required this.successRate,
    required this.totalCalls,
    required this.totalErrors,
  });
}

/// User satisfaction status
class SatisfactionStatus {
  final int satisfaction;
  final String trend;
  final int totalInteractions;
  final Map<String, dynamic>? lastFeedback;
  final int feedbackCount;

  SatisfactionStatus({
    required this.satisfaction,
    required this.trend,
    required this.totalInteractions,
    this.lastFeedback,
    required this.feedbackCount,
  });
}

/// Intelligent Algorithms for Chatbot Enhancement
/// Implements animal-inspired AI algorithms for smarter responses
class IntelligentAlgorithms {
  // ── ALGORITHM 1: Sentiment & Emotional Intelligence (Elephant Empathy) ──
  static SentimentResult analyzeSentiment(String text) {
    final positiveWords = {
      'great', 'excellent', 'wonderful', 'amazing', 'love', 'happy', 'excited',
      'fantastic', 'brilliant', 'perfect', 'awesome', 'good', 'nice', 'helpful',
      'thank', 'thanks', 'please', 'beautiful', 'joy', 'delighted'
    };
    final negativeWords = {
      'terrible', 'awful', 'horrible', 'hate', 'angry', 'sad', 'frustrated',
      'annoyed', 'disappointed', 'worried', 'confused', 'stupid', 'bad', 'wrong',
      'fail', 'error', 'problem', 'issue', 'difficult', 'hard'
    };
    final urgentWords = {
      'now', 'urgent', 'emergency', 'immediately', 'asap', 'help', 'quick',
      'fast', 'critical', 'important'
    };

    final words = text.toLowerCase().split(RegExp(r'\s+'));
    int posCount = 0, negCount = 0, urgCount = 0;

    for (final w in words) {
      final clean = w.replaceAll(RegExp(r'[^a-z]'), '');
      if (positiveWords.contains(clean)) posCount++;
      if (negativeWords.contains(clean)) negCount++;
      if (urgentWords.contains(clean)) urgCount++;
    }

    final total = words.length.clamp(1, double.infinity);
    final sentiment = (posCount - negCount) / total;
    final positivity = posCount / total;
    final negativity = negCount / total;
    final urgency = min(urgCount / 3, 1.0);
    final emotionalTone = posCount > negCount
        ? 'positive'
        : negCount > posCount
            ? 'negative'
            : 'neutral';

    return SentimentResult(
      sentiment: sentiment,
      positivity: positivity,
      negativity: negativity,
      urgency: urgency,
      emotionalTone: emotionalTone,
    );
  }

  // ── ALGORITHM 2: Uncertainty Estimation (Crow Metacognition) ──
  static double estimateUncertainty(String input) {
    final uncertaintyPatterns = [
      RegExp(r"what\s+is\s+the\s+(best|correct|right|exact|true)", caseSensitive: false),
      RegExp(r"how\s+do\s+i\s+know", caseSensitive: false),
      RegExp(r"can\s+you\s+(prove|confirm|verify|guarantee)", caseSensitive: false),
      RegExp(r"is\s+it\s+true\s+that", caseSensitive: false),
      RegExp(r"i\s+(?:don'?t\s+)?(understand|know|get|believe)\s+(that|if|whether|why)", caseSensitive: false),
      RegExp(r"explain\s+why", caseSensitive: false),
      RegExp(r"what\s+(happens|if|about)\s+when", caseSensitive: false),
      RegExp(r"\s+[a-z]+\s*/\s*[a-z]+\s"),
      RegExp(r"should\s+i\s+", caseSensitive: false),
      RegExp(r"which\s+one\s+should", caseSensitive: false),
    ];

    double uncertaintyScore = 0;
    for (final pattern in uncertaintyPatterns) {
      if (pattern.hasMatch(input)) uncertaintyScore += 0.15;
    }

    final vagueWords = {
      'something', 'anything', 'maybe', 'perhaps', 'possibly', 'might',
      'could', 'would', 'should', 'thing', 'stuff'
    };
    final words = input.toLowerCase().split(RegExp(r'\s+'));
    final vagueCount = words
        .where((w) => vagueWords.contains(w.replaceAll(RegExp(r'[^a-z]'), '')))
        .length;
    uncertaintyScore += min(vagueCount * 0.1, 0.4);

    if (RegExp(r'[\w]+\s*[\(\)\[\]\{\}\<\>]').hasMatch(input)) {
      uncertaintyScore += 0.1;
    }

    return min(uncertaintyScore, 1.0);
  }

  // ── ALGORITHM 3: Topic Modeling via Keyword Extraction (Ant Colony) ──
  static const Map<String, Set<String>> topicCategories = {
    'technology': {
      'code', 'program', 'software', 'computer', 'algorithm', 'data', 'api',
      'database', 'server', 'cloud', 'ai', 'machine', 'learning', 'neural',
      'network', 'python', 'javascript', 'html', 'css', 'react', 'node',
      'docker', 'kubernetes'
    },
    'science': {
      'physics', 'chemistry', 'biology', 'experiment', 'research', 'theory',
      'hypothesis', 'scientific', 'discovery', 'evolution', 'genetics',
      'molecule', 'atom', 'cell', 'organism'
    },
    'math': {
      'calculate', 'equation', 'formula', 'algebra', 'calculus', 'geometry',
      'statistic', 'probability', 'number', 'solve', 'theorem', 'proof',
      'integral', 'derivative', 'matrix'
    },
    'creative': {
      'write', 'story', 'poem', 'creative', 'art', 'design', 'music', 'draw',
      'paint', 'imagine', 'fiction', 'character', 'plot', 'narrative', 'metaphor'
    },
    'emotional': {
      'feel', 'emotion', 'happy', 'sad', 'angry', 'worried', 'anxious',
      'stressed', 'love', 'hate', 'fear', 'hope', 'dream', 'relationship', 'friend'
    },
    'practical': {
      'how', 'what', 'when', 'where', 'steps', 'guide', 'tutorial',
      'instruction', 'process', 'method', 'technique', 'strategy', 'plan',
      'organize', 'manage'
    },
    'philosophical': {
      'meaning', 'purpose', 'existence', 'consciousness', 'reality', 'truth',
      'knowledge', 'ethics', 'morality', 'philosophy', 'mind', 'soul', 'free',
      'will', 'nature'
    },
    'business': {
      'money', 'business', 'company', 'market', 'investment', 'profit',
      'strategy', 'customer', 'product', 'sales', 'marketing', 'finance',
      'economy', 'startup', 'entrepreneur'
    },
  };

  static List<TopicResult> extractTopics(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final topicScores = <String, double>{};

    topicCategories.forEach((topic, keywords) {
      double score = 0;
      for (final w in words) {
        final clean = w.replaceAll(RegExp(r'[^a-z]'), '');
        if (keywords.contains(clean)) {
          score += 1;
        } else if (keywords.any((k) => k.contains(clean) && clean.length > 2)) {
          score += 0.3;
        }
      }
      if (score > 0) topicScores[topic] = score;
    });

    final total = topicScores.values.fold<double>(0, (a, b) => a + b);
    if (total > 0) {
      topicScores.updateAll((_, v) => v / total);
    }

    final sorted = topicScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(3).map((e) => TopicResult(topic: e.key, score: e.value)).toList();
  }

  // ── ALGORITHM 4: Response Quality Scoring (Wolf Pack Deliberation) ──
  static double scoreResponseQuality(String response, String input) {
    double score = 0.5;

    final responseLen = response.length;
    final inputLen = input.length;
    final lenRatio = responseLen / max(inputLen, 10);
    if (lenRatio >= 0.5 && lenRatio <= 5) score += 0.1;
    if (responseLen < 20) score -= 0.2;

    final inputWords = input.toLowerCase().split(RegExp(r'\s+')).map((w) => w.replaceAll(RegExp(r'[^a-z]'), '')).toSet();
    final responseWords = response.toLowerCase().split(RegExp(r'\s+')).map((w) => w.replaceAll(RegExp(r'[^a-z]'), ''));
    int overlap = 0;
    for (final w in responseWords) {
      if (inputWords.contains(w) && w.length > 3) overlap++;
    }
    final relevanceRatio = overlap / max(responseWords.length, 1) * 10;
    if (relevanceRatio > 0.3) score += 0.15;

    final connectors = [
      'therefore', 'however', 'because', 'thus', 'consequently', 'moreover',
      'furthermore', 'in addition', 'on the other hand', 'as a result',
      'for example', 'in conclusion', 'specifically', 'particularly'
    ];
    if (connectors.any((c) => response.toLowerCase().contains(c))) score += 0.1;

    if (response.contains('\n\n') ||
        response.contains('- ') ||
        response.contains('1.') ||
        response.contains('•')) {
      score += 0.05;
    }

    final confidenceWords = [
      'definitely', 'certainly', 'clearly', 'obviously', 'undoubtedly',
      'absolutely', 'precisely', 'exactly'
    ];
    final uncertaintyWords = [
      'maybe', 'perhaps', 'possibly', 'might', 'could', 'seems', 'appears',
      'probably', 'likely', 'i think', 'i believe', 'in my opinion'
    ];
    final confCount = confidenceWords.where((w) => response.toLowerCase().contains(w)).length;
    final uncertCount = uncertaintyWords.where((w) => response.toLowerCase().contains(w)).length;
    if (confCount > uncertCount) score += 0.05;
    if (uncertCount > confCount) score -= 0.05;

    return max(0, min(1, score));
  }

  // ── ALGORITHM 5: Adaptive Response Strategy (Chromatophore Adaptation) ──
  static List<ResponseStrategy> determineResponseStrategy(
    String input,
    SentimentResult sentiment,
    List<TopicResult> topics,
    double uncertainty,
  ) {
    final strategies = <ResponseStrategy>[];

    if (sentiment.emotionalTone == 'negative') {
      strategies.add(ResponseStrategy(type: 'empathetic', weight: 0.8));
      strategies.add(ResponseStrategy(type: 'supportive', weight: 0.6));
    } else if (sentiment.emotionalTone == 'positive') {
      strategies.add(ResponseStrategy(type: 'enthusiastic', weight: 0.6));
      strategies.add(ResponseStrategy(type: 'encouraging', weight: 0.5));
    }

    if (sentiment.urgency > 0.5) {
      strategies.add(ResponseStrategy(type: 'concise', weight: 0.9));
      strategies.add(ResponseStrategy(type: 'actionable', weight: 0.7));
    }

    if (uncertainty > 0.5) {
      strategies.add(ResponseStrategy(type: 'clarifying', weight: uncertainty));
      strategies.add(ResponseStrategy(type: 'educational', weight: 0.6));
    }

    for (final t in topics) {
      if (t.topic == 'technology' || t.topic == 'math') {
        strategies.add(ResponseStrategy(type: 'technical', weight: t.score * 2));
      } else if (t.topic == 'creative') {
        strategies.add(ResponseStrategy(type: 'creative', weight: t.score * 2));
      } else if (t.topic == 'philosophical') {
        strategies.add(ResponseStrategy(type: 'reflective', weight: t.score * 2));
      } else if (t.topic == 'practical') {
        strategies.add(ResponseStrategy(type: 'instructional', weight: t.score * 2));
      }
    }

    if (strategies.isEmpty) {
      strategies.add(ResponseStrategy(type: 'informative', weight: 0.5));
    }

    strategies.sort((a, b) => b.weight.compareTo(a.weight));
    return strategies.take(3).toList();
  }

  // ── ALGORITHM 6: Semantic Similarity (Bat Echolocation) ──
  static double semanticSimilarity(String text1, String text2) {
    final words1 = text1.toLowerCase().split(RegExp(r'\s+')).map((w) => w.replaceAll(RegExp(r'[^a-z]'), '')).where((w) => w.length > 2).toSet();
    final words2 = text2.toLowerCase().split(RegExp(r'\s+')).map((w) => w.replaceAll(RegExp(r'[^a-z]'), '')).where((w) => w.length > 2).toSet();

    final intersection = words1.where((w) => words2.contains(w)).length;
    final union = words1.length + words2.length - intersection;
    return union > 0 ? intersection / union : 0;
  }
}

/// Network Health Monitor (Honeybee Waggle Dance Network)
class NetworkMonitor {
  final List<double> _latency = [];
  final List<int> _successRate = [];
  String _status = 'healthy';
  int _apiCalls = 0;
  int _apiErrors = 0;
  double _avgLatency = 0;
  double _connectionQuality = 1.0;

  void recordLatency(double ms) {
    _latency.add(ms);
    if (_latency.length > 50) _latency.removeAt(0);
    _avgLatency = _latency.reduce((a, b) => a + b) / _latency.length;
  }

  void recordSuccess() {
    _apiCalls++;
    _successRate.add(1);
    if (_successRate.length > 20) _successRate.removeAt(0);
    _updateStatus();
  }

  void recordError() {
    _apiCalls++;
    _apiErrors++;
    _successRate.add(0);
    if (_successRate.length > 20) _successRate.removeAt(0);
    _updateStatus();
  }

  void _updateStatus() {
    final recentCount = min(_successRate.length, 10);
    final recentSuccess = _successRate.isNotEmpty
        ? _successRate.sublist(_successRate.length - recentCount).reduce((a, b) => a + b) / recentCount
        : 1.0;
    final latencyHealth = _avgLatency < 1000 ? 1 : _avgLatency < 3000 ? 0.7 : _avgLatency < 5000 ? 0.4 : 0.2;
    _connectionQuality = (recentSuccess * 0.6 + latencyHealth * 0.4);

    if (_connectionQuality > 0.8) {
      _status = 'healthy';
    } else if (_connectionQuality > 0.5) {
      _status = 'degraded';
    } else if (_connectionQuality > 0.2) {
      _status = 'poor';
    } else {
      _status = 'offline';
    }
  }

  NetworkStatus getStatus() {
    final recentCount = min(_successRate.length, 10);
    final recentSuccess = _successRate.isNotEmpty
        ? _successRate.sublist(_successRate.length - recentCount).reduce((a, b) => a + b) / recentCount
        : 1.0;
    return NetworkStatus(
      status: _status,
      quality: _connectionQuality,
      avgLatency: _avgLatency.round(),
      successRate: (recentSuccess * 100).round(),
      totalCalls: _apiCalls,
      totalErrors: _apiErrors,
    );
  }

  void reset() {
    _latency.clear();
    _successRate.clear();
    _apiCalls = 0;
    _apiErrors = 0;
    _status = 'healthy';
    _connectionQuality = 1.0;
  }
}

/// User Satisfaction Tracker (Dolphin Social Bonding)
class SatisfactionTracker {
  final List<double> _scores = [];
  final List<Map<String, dynamic>> _interactions = [];
  double _overallSatisfaction = 0.7;
  String _trend = 'stable';
  Map<String, dynamic>? _lastFeedback;
  final List<Map<String, dynamic>> _feedbackHistory = [];

  double recordInteraction(String userInput, String response, double responseTime, double quality) {
    final implicitScore = calculateImplicitScore(userInput, response, responseTime, quality);

    _interactions.add({
      'timestamp': DateTime.now().toIso8601String(),
      'input': userInput,
      'response': response,
      'responseTime': responseTime,
      'quality': quality,
      'implicitScore': implicitScore,
    });
    if (_interactions.length > 100) _interactions.removeAt(0);

    _scores.add(implicitScore);
    if (_scores.length > 50) _scores.removeAt(0);

    _overallSatisfaction = _scores.reduce((a, b) => a + b) / _scores.length;
    _trend = calculateTrend();

    return implicitScore;
  }

  double calculateImplicitScore(String input, String response, double responseTime, double quality) {
    double score = 0.7;

    score += quality * 0.2;

    if (responseTime > 10000) {
      score -= 0.15;
    } else if (responseTime > 5000) {
      score -= 0.05;
    } else if (responseTime < 2000) {
      score += 0.05;
    }

    final lenRatio = response.length / max(input.length, 10);
    if (lenRatio >= 1 && lenRatio <= 4) {
      score += 0.05;
    } else if (lenRatio < 0.5 || lenRatio > 8) {
      score -= 0.1;
    }

    final engagementWords = [
      'great', 'thanks', 'perfect', 'exactly', 'helpful', 'awesome', 'love',
      'amazing', 'brilliant'
    ];
    final disengagementWords = [
      'wrong', 'not helpful', 'confusing', 'unclear', 'bad', 'terrible', 'useless'
    ];
    final inputLower = input.toLowerCase();

    if (engagementWords.any((w) => inputLower.contains(w))) score += 0.15;
    if (disengagementWords.any((w) => inputLower.contains(w))) score -= 0.2;

    return max(0, min(1, score));
  }

  String calculateTrend() {
    if (_scores.length < 5) return 'stable';

    final recent = _scores.sublist(_scores.length - 5);
    final olderCount = min(_scores.length, 10);
    final olderSublist = _scores.sublist(_scores.length - olderCount);
    final older = olderSublist.take(5);

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.isNotEmpty ? older.reduce((a, b) => a + b) / older.length : recentAvg;

    final diff = recentAvg - olderAvg;

    if (diff > 0.1) return 'improving';
    else if (diff < -0.1) return 'declining';
    else return 'stable';
  }

  void explicitFeedback(int score, String comment) {
    _lastFeedback = {
      'score': score,
      'comment': comment,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _feedbackHistory.add(_lastFeedback!);
    if (_feedbackHistory.length > 20) _feedbackHistory.removeAt(0);

    _scores.add(score / 5); // Normalize to 0-1
    if (_scores.length > 50) _scores.removeAt(0);
    _overallSatisfaction = _scores.reduce((a, b) => a + b) / _scores.length;
    _trend = calculateTrend();
  }

  SatisfactionStatus getStatus() {
    return SatisfactionStatus(
      satisfaction: (_overallSatisfaction * 100).round(),
      trend: _trend,
      totalInteractions: _interactions.length,
      lastFeedback: _lastFeedback,
      feedbackCount: _feedbackHistory.length,
    );
  }

  void reset() {
    _scores.clear();
    _interactions.clear();
    _overallSatisfaction = 0.7;
    _trend = 'stable';
    _lastFeedback = null;
    _feedbackHistory.clear();
  }
}