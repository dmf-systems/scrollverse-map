import { generateKeyPairSync, randomUUID, sign, verify } from 'crypto';

export const DMF7_DID_PREFIX = 'did:dmf7:';

export type IdentityKind = 'node' | 'agent';

export interface IdentityRecord {
  did: string;
  type: IdentityKind;
  publicKey: string;
  privateKey: string;
  createdAt: Date;
  metadata?: Record<string, unknown>;
}

const normalizePayload = (payload: unknown): Buffer =>
  Buffer.from(typeof payload === 'string' ? payload : JSON.stringify(payload));

export const buildDid = (type: IdentityKind, uniqueId?: string): string => {
  const suffix = uniqueId ?? randomUUID();
  return `${DMF7_DID_PREFIX}${type}:${suffix}`;
};

export const createIdentity = (
  type: IdentityKind,
  uniqueId?: string,
  metadata?: Record<string, unknown>
): IdentityRecord => {
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');

  return {
    did: buildDid(type, uniqueId),
    type,
    publicKey: publicKey.export({ format: 'pem', type: 'spki' }).toString(),
    privateKey: privateKey.export({ format: 'pem', type: 'pkcs8' }).toString(),
    metadata,
    createdAt: new Date(),
  };
};

export const signIdentityPayload = (identity: IdentityRecord, payload: unknown): string =>
  sign(null, normalizePayload(payload), identity.privateKey).toString('base64');

export const verifyIdentitySignature = (
  identity: IdentityRecord,
  payload: unknown,
  signature: string
): boolean => verify(null, normalizePayload(payload), identity.publicKey, Buffer.from(signature, 'base64'));

export class IdentityRegistry {
  private readonly registry = new Map<string, IdentityRecord>();

  register(identity: IdentityRecord): IdentityRecord {
    this.validateDid(identity);

    if (this.registry.has(identity.did)) {
      throw new Error(`Identity already registered: ${identity.did}`);
    }

    this.registry.set(identity.did, identity);
    return identity;
  }

  get(did: string): IdentityRecord | undefined {
    return this.registry.get(did);
  }

  has(did: string): boolean {
    return this.registry.has(did);
  }

  list(type?: IdentityKind): IdentityRecord[] {
    return [...this.registry.values()].filter((identity) => !type || identity.type === type);
  }

  verify(did: string, payload: unknown, signature: string): boolean {
    const identity = this.registry.get(did);
    if (!identity) {
      return false;
    }

    return verifyIdentitySignature(identity, payload, signature);
  }

  private validateDid(identity: IdentityRecord): void {
    if (!identity.did.startsWith(DMF7_DID_PREFIX)) {
      throw new Error(`Invalid DID prefix for identity: ${identity.did}`);
    }

    const suffix = identity.did.slice(DMF7_DID_PREFIX.length);
    const [kind, uniqueId] = suffix.split(':');

    if (!kind || !uniqueId) {
      throw new Error(`Malformed DID, expected did:dmf7:<type>:<id> but received ${identity.did}`);
    }

    if (kind !== identity.type) {
      throw new Error(`Identity kind mismatch for ${identity.did}: expected ${identity.type}`);
    }
  }
}
