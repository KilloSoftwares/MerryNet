import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';
import path from 'path';
import { config } from '../config';
import { logger } from '../utils/logger';

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

/**
 * gRPC client for the Go Gateway Service
 */
class GatewayClient {
  private client: any;

  constructor() {
    const address = `${config.gateway.host}:${config.gateway.grpcPort}`;
    this.client = new maranet.GatewayService(
      address,
      grpc.credentials.createInsecure()
    );
    logger.info(`🔌 Gateway gRPC client initialized for ${address}`);
  }

  /**
   * Add a tunnel from a reseller node to the gateway
   */
  async addTunnel(nodeId: string, publicKey: string, endpoint: string, subnet: string): Promise<any> {
    return new Promise((resolve, reject) => {
      this.client.AddTunnel(
        {
          node_id: nodeId,
          node_public_key: publicKey,
          node_endpoint: endpoint,
          assigned_subnet: subnet,
        },
        (error: any, response: any) => {
          if (error) {
            logger.error(`❌ Failed to add gateway tunnel for node ${nodeId}:`, error.message);
            return reject(error);
          }
          logger.info(`✅ Gateway tunnel added for node ${nodeId}`);
          resolve(response);
        }
      );
    });
  }

  /**
   * Remove a tunnel from the gateway
   */
  async removeTunnel(nodeId: string, publicKey: string): Promise<any> {
    return new Promise((resolve, reject) => {
      this.client.RemoveTunnel(
        {
          node_id: nodeId,
          node_public_key: publicKey,
        },
        (error: any, response: any) => {
          if (error) {
            logger.error(`❌ Failed to remove gateway tunnel for node ${nodeId}:`, error.message);
            return reject(error);
          }
          logger.info(`🗑️ Gateway tunnel removed for node ${nodeId}`);
          resolve(response);
        }
      );
    });
  }
}

export const gatewayClient = new GatewayClient();
