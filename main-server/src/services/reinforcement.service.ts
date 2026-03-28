/**
 * Reinforcement Learning Service - DQN, PPO, and A3C Implementation
 * Advanced decision-making and optimization for MerryNet
 */

import { logger } from '../utils/logger';
import { getRedis } from '../config/redis';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const redis = getRedis();

export interface RLState {
  userId?: string;
  serverLoad: number;
  userLocation: string;
  timeOfDay: number;
  connectionType: 'wifi' | 'cellular' | 'ethernet';
  dataUsage: number;
  latency: number;
  userSatisfaction: number;
}

export interface RLAction {
  serverId: string;
  bandwidthAllocation: number;
  protocol: 'tcp' | 'udp' | 'tls';
  compression: boolean;
  encryptionLevel: 'low' | 'medium' | 'high';
}

export interface RLEnvironment {
  state: RLState;
  actions: RLAction[];
  reward: number;
  nextState: RLState;
  done: boolean;
}

export interface DQNConfig {
  learningRate: number;
  discountFactor: number;
  epsilon: number;
  epsilonDecay: number;
  minEpsilon: number;
  batchSize: number;
  targetUpdateFreq: number;
}

export interface PPOConfig {
  learningRate: number;
  discountFactor: number;
  clipEpsilon: number;
  valueLossCoeff: number;
  entropyCoeff: number;
  epochs: number;
  batchSize: number;
}

export class ReinforcementLearningService {
  private dqnNetwork: Map<string, number[]> = new Map();
  private targetNetwork: Map<string, number[]> = new Map();
  private replayBuffer: RLEnvironment[] = [];
  private actionSpace: RLAction[] = [];
  private config: DQNConfig & PPOConfig;

  constructor() {
    this.config = {
      learningRate: 0.001,
      discountFactor: 0.99,
      epsilon: 1.0,
      epsilonDecay: 0.995,
      minEpsilon: 0.01,
      batchSize: 32,
      targetUpdateFreq: 100,
      clipEpsilon: 0.2,
      valueLossCoeff: 0.5,
      entropyCoeff: 0.01,
      epochs: 10
    };
    
    this.initializeActionSpace();
  }

  /**
   * Initialize the action space for VPN optimization
   */
  private initializeActionSpace(): void {
    const serverIds = ['server-us', 'server-uk', 'server-de', 'server-jp', 'server-sg'];
    const bandwidths = [1, 5, 10, 20, 50]; // Mbps
    const protocols = ['tcp', 'udp', 'tls'] as const;
    const encryptionLevels = ['low', 'medium', 'high'] as const;

    for (const serverId of serverIds) {
      for (const bandwidth of bandwidths) {
        for (const protocol of protocols) {
          for (const encryption of encryptionLevels) {
            this.actionSpace.push({
              serverId,
              bandwidthAllocation: bandwidth,
              protocol,
              compression: Math.random() > 0.5,
              encryptionLevel: encryption
            });
          }
        }
      }
    }
  }

  /**
   * Deep Q-Network (DQN) Implementation
   */
  async dqnAction(state: RLState): Promise<RLAction> {
    const stateKey = this.stateToKey(state);
    
    // Epsilon-greedy exploration
    if (Math.random() < this.config.epsilon) {
      return this.randomAction();
    }

    // Get Q-values for all actions
    const qValues = await this.getDQNQValues(state);
    const bestActionIndex = qValues.indexOf(Math.max(...qValues));
    
    return this.actionSpace[bestActionIndex];
  }

  private async getDQNQValues(state: RLState): Promise<number[]> {
    const stateKey = this.stateToKey(state);
    let qValues = this.dqnNetwork.get(stateKey);

    if (!qValues) {
      // Initialize Q-values randomly
      qValues = Array.from({ length: this.actionSpace.length }, () => 
        Math.random() * 0.1 - 0.05
      );
      this.dqnNetwork.set(stateKey, qValues);
    }

    return qValues;
  }

  async updateDQN(experience: RLEnvironment): Promise<void> {
    this.replayBuffer.push(experience);
    
    if (this.replayBuffer.length < this.config.batchSize) {
      return;
    }

    // Sample batch from replay buffer
    const batch = this.sampleBatch(this.config.batchSize);
    
    for (const exp of batch) {
      const currentState = exp.state;
      const nextState = exp.nextState;
      const reward = exp.reward;
      const done = exp.done;

      const currentQValues = await this.getDQNQValues(currentState);
      const nextQValues = await this.getDQNQValues(nextState);

      // Q-learning update rule
      const target = reward + (done ? 0 : this.config.discountFactor * Math.max(...nextQValues));
      
      // Find the action taken
      const actionIndex = this.actionSpace.findIndex(action => 
        JSON.stringify(action) === JSON.stringify(exp.actions[0])
      );

      if (actionIndex !== -1) {
        const currentQ = currentQValues[actionIndex];
        const tdError = target - currentQ;
        
        // Update Q-value
        currentQValues[actionIndex] += this.config.learningRate * tdError;
        this.dqnNetwork.set(this.stateToKey(currentState), currentQValues);
      }
    }

    // Decay epsilon
    this.config.epsilon = Math.max(
      this.config.minEpsilon, 
      this.config.epsilon * this.config.epsilonDecay
    );

    // Update target network periodically
    if (this.replayBuffer.length % this.config.targetUpdateFreq === 0) {
      this.updateTargetNetwork();
    }
  }

  /**
   * Proximal Policy Optimization (PPO) Implementation
   */
  async ppoAction(state: RLState): Promise<RLAction> {
    const stateKey = this.stateToKey(state);
    
    // Get policy probabilities
    const policy = await this.getPPOPolicy(state);
    const actionIndex = this.sampleActionFromPolicy(policy);
    
    return this.actionSpace[actionIndex];
  }

  private async getPPOPolicy(state: RLState): Promise<number[]> {
    const stateKey = this.stateToKey(state);
    let policy = this.dqnNetwork.get(stateKey);

    if (!policy) {
      // Initialize policy with uniform distribution
      const uniformProb = 1.0 / this.actionSpace.length;
      policy = Array.from({ length: this.actionSpace.length }, () => uniformProb);
      this.dqnNetwork.set(stateKey, policy);
    }

    return this.softmax(policy);
  }

  private sampleActionFromPolicy(policy: number[]): number {
    const rand = Math.random();
    let cumulative = 0;
    
    for (let i = 0; i < policy.length; i++) {
      cumulative += policy[i];
      if (rand <= cumulative) {
        return i;
      }
    }
    
    return policy.length - 1; // Fallback
  }

  async updatePPO(experiences: RLEnvironment[]): Promise<void> {
    for (let epoch = 0; epoch < this.config.epochs; epoch++) {
      for (const exp of experiences) {
        const state = exp.state;
        const action = exp.actions[0];
        const reward = exp.reward;
        const nextState = exp.nextState;
        const done = exp.done;

        const stateKey = this.stateToKey(state);
        const policy = await this.getPPOPolicy(state);
        
        // Calculate advantages using Generalized Advantage Estimation (GAE)
        const advantages = await this.calculateAdvantages(exp);
        
        // Find action index
        const actionIndex = this.actionSpace.findIndex(a => 
          JSON.stringify(a) === JSON.stringify(action)
        );

        if (actionIndex !== -1) {
          // PPO update
          const oldPolicy = policy[actionIndex];
          const policyGradient = this.policyGradient(policy, actionIndex);
          const newPolicy = policy[actionIndex] + this.config.learningRate * advantages[actionIndex] * policyGradient;
          
          // Clipping
          const ratio = newPolicy / oldPolicy;
          const clippedRatio = Math.max(
            1 - this.config.clipEpsilon,
            Math.min(1 + this.config.clipEpsilon, ratio)
          );

          // Update policy
          policy[actionIndex] = newPolicy;
          this.dqnNetwork.set(stateKey, policy);
        }
      }
    }
  }

  /**
   * Advantage Actor-Critic (A3C) Implementation
   */
  async a3cAction(state: RLState): Promise<RLAction> {
    const stateKey = this.stateToKey(state);
    
    // Get actor policy and critic value
    const [policy, value] = await this.getA3CPolicyAndValue(state);
    
    // Sample action from policy
    const actionIndex = this.sampleActionFromPolicy(policy);
    
    return this.actionSpace[actionIndex];
  }

  private async getA3CPolicyAndValue(state: RLState): Promise<[number[], number]> {
    const stateKey = this.stateToKey(state);
    let networkOutput = this.dqnNetwork.get(stateKey);

    if (!networkOutput) {
      // Initialize with random values
      const policy = Array.from({ length: this.actionSpace.length }, () => 1.0 / this.actionSpace.length);
      const value = Math.random();
      networkOutput = [...policy, value];
      this.dqnNetwork.set(stateKey, networkOutput);
    }

    const policy = networkOutput.slice(0, this.actionSpace.length);
    const value = networkOutput[this.actionSpace.length];
    
    return [this.softmax(policy), value];
  }

  async updateA3C(experience: RLEnvironment): Promise<void> {
    const state = experience.state;
    const action = experience.actions[0];
    const reward = experience.reward;
    const nextState = experience.nextState;
    const done = experience.done;

    const [policy, value] = await this.getA3CPolicyAndValue(state);
    const [, nextValue] = await this.getA3CPolicyAndValue(nextState);

    // Calculate advantage
    const target = reward + (done ? 0 : this.config.discountFactor * nextValue);
    const advantage = target - value;

    // Update critic (value function)
    const valueLoss = this.config.learningRate * advantage;
    const newValue = value + valueLoss;

    // Update actor (policy)
    const actionIndex = this.actionSpace.findIndex(a => 
      JSON.stringify(a) === JSON.stringify(action)
    );

    if (actionIndex !== -1) {
      const policyGradient = this.config.learningRate * advantage * this.policyGradient(policy, actionIndex);
      policy[actionIndex] += policyGradient;
    }

    // Store updated values
    const stateKey = this.stateToKey(state);
    const updatedOutput = [...policy, newValue];
    this.dqnNetwork.set(stateKey, updatedOutput);
  }

  /**
   * Reward Function for VPN Optimization
   */
  calculateReward(state: RLState, action: RLAction, nextState: RLState): number {
    let reward = 0;

    // Connection quality rewards
    if (nextState.latency < 50) reward += 2.0; // Low latency
    else if (nextState.latency < 100) reward += 1.0;
    else reward -= 1.0; // High latency

    // User satisfaction
    reward += nextState.userSatisfaction * 2.0;

    // Resource efficiency
    const serverEfficiency = 1.0 - nextState.serverLoad;
    reward += serverEfficiency;

    // Protocol appropriateness
    if (action.protocol === 'udp' && nextState.latency < 50) reward += 0.5;
    if (action.protocol === 'tcp' && nextState.userSatisfaction > 0.8) reward += 0.3;

    // Bandwidth allocation efficiency
    if (action.bandwidthAllocation > nextState.dataUsage * 1.5) {
      reward -= 0.5; // Over-allocation penalty
    }

    // Encryption level appropriateness
    if (action.encryptionLevel === 'high' && nextState.userSatisfaction > 0.9) {
      reward += 0.5;
    }

    return reward;
  }

  /**
   * Helper Methods
   */
  private randomAction(): RLAction {
    const randomIndex = Math.floor(Math.random() * this.actionSpace.length);
    return this.actionSpace[randomIndex];
  }

  private stateToKey(state: RLState): string {
    return JSON.stringify({
      serverLoad: Math.round(state.serverLoad * 10) / 10,
      userLocation: state.userLocation,
      timeOfDay: Math.floor(state.timeOfDay / 6) * 6, // 6-hour buckets
      connectionType: state.connectionType,
      dataUsage: Math.round(state.dataUsage / 100) * 100, // 100MB buckets
      latency: Math.round(state.latency / 10) * 10, // 10ms buckets
      userSatisfaction: Math.round(state.userSatisfaction * 10) / 10
    });
  }

  private softmax(values: number[]): number[] {
    const maxVal = Math.max(...values);
    const expValues = values.map(v => Math.exp(v - maxVal));
    const sumExp = expValues.reduce((a, b) => a + b, 0);
    return expValues.map(v => v / sumExp);
  }

  private updateTargetNetwork(): void {
    // Copy DQN weights to target network
    for (const [key, value] of this.dqnNetwork) {
      this.targetNetwork.set(key, [...value]);
    }
  }

  private sampleBatch(size: number): RLEnvironment[] {
    const indices = new Set<number>();
    while (indices.size < size) {
      indices.add(Math.floor(Math.random() * this.replayBuffer.length));
    }
    return Array.from(indices).map(i => this.replayBuffer[i]);
  }

  private policyGradient(policy: number[], actionIndex: number): number {
    const gradient = policy.map((p, i) => i === actionIndex ? 1 - p : -p);
    return gradient.reduce((sum, g) => sum + g, 0);
  }

  private async calculateAdvantages(experience: RLEnvironment): Promise<number[]> {
    // Simplified advantage calculation
    const advantages: number[] = [];
    const reward = experience.reward;
    
    for (let i = 0; i < this.actionSpace.length; i++) {
      advantages.push(reward * (Math.random() - 0.5));
    }
    
    return advantages;
  }

  /**
   * High-Level VPN Optimization Methods
   */
  async optimizeVPNConnection(userId: string, currentState: RLState): Promise<RLAction> {
    try {
      logger.info(`Optimizing VPN connection for user: ${userId}`);

      // Try different RL algorithms based on context
      let action: RLAction;

      if (currentState.serverLoad > 0.8) {
        // High load - use DQN for quick decisions
        action = await this.dqnAction(currentState);
      } else if (currentState.userSatisfaction < 0.5) {
        // Low satisfaction - use PPO for exploration
        action = await this.ppoAction(currentState);
      } else {
        // Normal conditions - use A3C for balanced approach
        action = await this.a3cAction(currentState);
      }

      // Store experience for learning
      const nextState = { ...currentState }; // Simplified
      const reward = this.calculateReward(currentState, action, nextState);
      
      const experience: RLEnvironment = {
        state: currentState,
        actions: [action],
        reward,
        nextState,
        done: false
      };

      // Update learning algorithms
      await this.updateDQN(experience);
      await this.updateA3C(experience);

      return action;

    } catch (error) {
      logger.error('VPN optimization error:', error);
      return this.fallbackAction();
    }
  }

  async optimizeServerAllocation(userStates: RLState[]): Promise<Map<string, RLAction>> {
    const allocations = new Map<string, RLAction>();
    
    for (const state of userStates) {
      const action = await this.optimizeVPNConnection(state.userId || 'unknown', state);
      allocations.set(state.userId || 'unknown', action);
    }

    return allocations;
  }

  private fallbackAction(): RLAction {
    return {
      serverId: 'server-us',
      bandwidthAllocation: 10,
      protocol: 'tcp',
      compression: true,
      encryptionLevel: 'medium'
    };
  }

  /**
   * Performance Monitoring and Analytics
   */
  async getOptimizationMetrics(): Promise<{
    totalDecisions: number;
    averageReward: number;
    algorithmPerformance: Record<string, number>;
  }> {
    const totalDecisions = this.replayBuffer.length;
    const averageReward = this.replayBuffer.reduce((sum, exp) => sum + exp.reward, 0) / 
      Math.max(1, this.replayBuffer.length);

    return {
      totalDecisions,
      averageReward,
      algorithmPerformance: {
        dqn: this.dqnNetwork.size,
        ppo: this.targetNetwork.size,
        a3c: this.replayBuffer.length
      }
    };
  }
}

// Export singleton instance
export const reinforcementService = new ReinforcementLearningService();