import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';
import path from 'path';
import { config } from '../config';
import { prisma } from '../config/database';
import { logger } from '../utils/logger';
import { generateWireGuardKeys } from '../utils/helpers';

// ============================================================
// Proto Loading
// ============================================================

const PROTO_PATH = path.resolve(__dirname, '../../../proto/maranet.proto');

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const protoDescriptor = grpc.loadPackageDefinition(packageDefinition) as any;
const maranet = protoDescriptor.maranet;

// ============================================================
// Connected Nodes Registry
// ============================================================

interface ConnectedNode {
  nodeId: string;
  resellerId: string;
  publicKey: string;
  endpoint: string;
  platform: string;
  capacity: number;
  activePeers: number;
  lastHeartbeat: Date;
  commandStream?: grpc.ServerWritableStream<any, any>;
}

const connectedNodes = new Map<string, ConnectedNode>();

// ============================================================
// NodeService Implementation
// ============================================================

/**
 * RegisterNode — Reseller node registration
 */
async function registerNode(
  call: grpc.ServerUnaryCall<any, any>,
  callback: grpc.sendUnaryData<any>
) {
  try {
    const req = call.request;
    logger.info(`📡 Node registration request: ${req.device_id} (${req.platform})`);

    // Find reseller by device_id
    const node = await prisma.reseller.findFirst({
      where: { deviceId: req.device_id },
    });

    if (!node) {
      return callback({
        code: grpc.status.NOT_FOUND,
        message: 'Node not registered. Please register through the app first.',
      });
    }

    // Generate server-side WireGuard keys for the tunnel
    const { publicKey: serverPubKey } = generateWireGuardKeys();

    // Assign subnet to the node
    const subnet = `10.0.${(connectedNodes.size + 1) % 255}.0/24`;

    // Store node info
    connectedNodes.set(req.device_id, {
      nodeId: req.device_id,
      resellerId: node.id,
      publicKey: req.public_key,
      endpoint: req.endpoint,
      platform: req.platform,
      capacity: req.capacity || 50,
      activePeers: 0,
      lastHeartbeat: new Date(),
    });

    // Update node status in DB
    await prisma.reseller.update({
      where: { id: node.id },
      data: {
        isOnline: true,
        publicKey: req.public_key,
        endpoint: req.endpoint,
        lastSeen: new Date(),
      },
    });

    logger.info(`✅ Node registered: ${req.device_id}, subnet=${subnet}`);

    callback(null, {
      success: true,
      node_id: req.device_id,
      assigned_subnet: subnet,
      server_public_key: serverPubKey,
      server_endpoint: `${config.host}:51820`,
      heartbeat_interval: 30,
    });
  } catch (error: any) {
    logger.error('RegisterNode error:', error);
    callback({
      code: grpc.status.INTERNAL,
      message: error.message,
    });
  }
}

/**
 * Heartbeat — Bidirectional streaming for health updates
 */
function heartbeat(call: grpc.ServerDuplexStream<any, any>) {
  let nodeId = '';

  call.on('data', async (heartbeat: any) => {
    nodeId = heartbeat.node_id;
    const node = connectedNodes.get(nodeId);

    if (node) {
      node.lastHeartbeat = new Date();
      node.activePeers = heartbeat.active_peers || 0;

      // Update DB periodically (every 5th heartbeat)
      try {
        await prisma.reseller.updateMany({
          where: { deviceId: nodeId },
          data: {
            isOnline: true,
            lastSeen: new Date(),
            activePeers: heartbeat.active_peers || 0,
          },
        });
      } catch (err) {
        logger.warn(`Failed to update heartbeat for ${nodeId}`);
      }

      // Acknowledge heartbeat
      call.write({
        acknowledged: true,
        server_time: { seconds: Math.floor(Date.now() / 1000) },
      });
    }
  });

  call.on('end', () => {
    if (nodeId) {
      logger.info(`💔 Heartbeat stream ended for node: ${nodeId}`);
      const node = connectedNodes.get(nodeId);
      if (node) {
        prisma.reseller.updateMany({
          where: { deviceId: nodeId },
          data: { isOnline: false },
        }).catch(() => {});
      }
    }
    call.end();
  });

  call.on('error', (err: any) => {
    logger.warn(`Heartbeat stream error for ${nodeId}:`, err.message);
  });
}

/**
 * CommandStream — Server pushes commands to nodes
 */
function commandStream(call: grpc.ServerWritableStream<any, any>) {
  const nodeId = call.request.node_id;
  const node = connectedNodes.get(nodeId);

  if (!node) {
    call.end();
    return;
  }

  // Store the stream so we can push commands later
  node.commandStream = call;
  logger.info(`🔗 Command stream opened for node: ${nodeId}`);

  call.on('cancelled', () => {
    logger.info(`Command stream cancelled for node: ${nodeId}`);
    if (node.commandStream === call) {
      node.commandStream = undefined;
    }
  });

  call.on('error', (err: any) => {
    logger.warn(`Command stream error for ${nodeId}:`, err.message);
    if (node.commandStream === call) {
      node.commandStream = undefined;
    }
  });
}

// ============================================================
// Peer Management (called by SubscriptionService)
// ============================================================

/**
 * Send a CreatePeer command to a reseller node
 */
export async function sendCreatePeer(
  nodeId: string,
  userId: string,
  subscriptionId: string,
  publicKey: string,
  allowedIp: string,
  expiresAt: Date
): Promise<boolean> {
  const node = connectedNodes.get(nodeId);
  if (!node || !node.commandStream) {
    logger.warn(`Cannot send CreatePeer to node ${nodeId}: not connected`);
    return false;
  }

  try {
    node.commandStream.write({
      command_id: `cmd-${Date.now()}`,
      create_peer: {
        user_id: userId,
        subscription_id: subscriptionId,
        public_key: publicKey,
        allowed_ip: allowedIp,
        expires_at: { seconds: Math.floor(expiresAt.getTime() / 1000) },
      },
    });
    logger.info(`📤 Sent CreatePeer to ${nodeId} for user ${userId}`);
    return true;
  } catch (error: any) {
    logger.error(`Failed to send CreatePeer to ${nodeId}:`, error.message);
    return false;
  }
}

/**
 * Send a RemovePeer command to a reseller node
 */
export async function sendRemovePeer(
  nodeId: string,
  publicKey: string
): Promise<boolean> {
  const node = connectedNodes.get(nodeId);
  if (!node || !node.commandStream) {
    return false;
  }

  try {
    node.commandStream.write({
      command_id: `cmd-${Date.now()}`,
      remove_peer: {
        public_key: publicKey,
        reason: 'subscription_expired',
      },
    });
    return true;
  } catch (error: any) {
    logger.error(`Failed to send RemovePeer to ${nodeId}:`, error.message);
    return false;
  }
}

/**
 * Get a list of online nodes with available capacity
 */
export function getAvailableNodes(): ConnectedNode[] {
  const nodes: ConnectedNode[] = [];
  for (const [, node] of connectedNodes) {
    const isRecent = Date.now() - node.lastHeartbeat.getTime() < 90000; // 90s
    if (isRecent && node.activePeers < node.capacity) {
      nodes.push(node);
    }
  }
  // Sort by least loaded
  return nodes.sort((a, b) => a.activePeers - b.activePeers);
}

/**
 * Get connected node count
 */
export function getConnectedNodeCount(): number {
  return connectedNodes.size;
}

// ============================================================
// gRPC Server
// ============================================================

export function startGrpcServer(): grpc.Server {
  const server = new grpc.Server({
    'grpc.max_receive_message_length': 10 * 1024 * 1024,
    'grpc.max_send_message_length': 10 * 1024 * 1024,
    'grpc.keepalive_time_ms': 30000,
    'grpc.keepalive_timeout_ms': 10000,
  });

  // Register services
  server.addService(maranet.NodeService.service, {
    RegisterNode: registerNode,
    Heartbeat: heartbeat,
    CommandStream: commandStream,
  });

  const address = `${config.grpc.host}:${config.grpc.port}`;

  server.bindAsync(
    address,
    grpc.ServerCredentials.createInsecure(),
    (error, port) => {
      if (error) {
        logger.error('❌ Failed to start gRPC server:', error);
        return;
      }
      logger.info(`🔌 gRPC server listening on ${address}`);
    }
  );

  return server;
}

export function stopGrpcServer(server: grpc.Server): Promise<void> {
  return new Promise((resolve) => {
    server.tryShutdown(() => {
      logger.info('gRPC server stopped');
      resolve();
    });
  });
}
