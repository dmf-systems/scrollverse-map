import { createIdentity, IdentityRecord } from './identity-registry';

export type NodeIdentity = IdentityRecord & { type: 'node' };

export interface CreateNodeIdentityOptions {
  uniqueId?: string;
  metadata?: Record<string, unknown>;
}

export const createNodeIdentity = (options?: CreateNodeIdentityOptions): NodeIdentity =>
  createIdentity('node', options?.uniqueId, options?.metadata) as NodeIdentity;
