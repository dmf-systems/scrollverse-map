import { createIdentity, IdentityRecord } from './identity-registry';

export type AgentIdentity = IdentityRecord & { type: 'agent' };

export interface CreateAgentIdentityOptions {
  uniqueId?: string;
  metadata?: Record<string, unknown>;
}

export const createAgentIdentity = (options?: CreateAgentIdentityOptions): AgentIdentity =>
  createIdentity('agent', options?.uniqueId, options?.metadata) as AgentIdentity;
