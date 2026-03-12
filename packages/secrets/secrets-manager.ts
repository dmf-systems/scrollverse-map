import { createDecipheriv, createCipheriv, randomBytes, createHash } from "crypto";
import { readFileSync, existsSync, writeFileSync } from "fs";
import { resolve } from "path";

type SecretPayload = {
  iv: string;
  authTag: string;
  value: string;
};

export type VaultRecord = Record<string, SecretPayload>;

export interface SecretsManagerOptions {
  masterKey: string;
  vaultFile?: string;
  preloadVault?: VaultRecord;
  envFile?: string;
}

const algorithm = "aes-256-gcm";

const parseEnvFile = (filePath: string): Record<string, string> => {
  const absolute = resolve(filePath);
  if (!existsSync(absolute)) {
    return {};
  }
  const lines = readFileSync(absolute, "utf8").split("\n");
  const env: Record<string, string> = {};
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) continue;
    const [key = "", ...rest] = line.split("=");
    if (!key) continue;
    env[key.trim()] = rest.join("=").trim();
  }
  return env;
};

const deriveKey = (passphrase: string): Buffer => {
  const hash = createHash("sha256").update(passphrase).digest();
  return hash;
};

export class SecretsManager {
  private readonly vault: VaultRecord;
  private readonly masterKey: Buffer;
  private readonly vaultFile?: string;

  constructor(options: SecretsManagerOptions) {
    this.masterKey = deriveKey(options.masterKey);
    this.vaultFile = options.vaultFile ? resolve(options.vaultFile) : undefined;
    this.vault = { ...(options.preloadVault ?? {}) };

    if (options.envFile) {
      this.loadEnv(options.envFile);
    }

    if (this.vaultFile && existsSync(this.vaultFile)) {
      try {
        const diskVault = JSON.parse(readFileSync(this.vaultFile, "utf8")) as VaultRecord;
        Object.assign(this.vault, diskVault);
      } catch {
        // ignore unreadable vault file
      }
    }

    const fromEnv = process.env.VAULT_SECRETS;
    if (fromEnv) {
      try {
        const parsed = JSON.parse(fromEnv) as VaultRecord;
        Object.assign(this.vault, parsed);
      } catch {
        // ignore invalid JSON to avoid crashing services at startup
      }
    }
  }

  static fromEnvironment(): SecretsManager {
    const masterKey = process.env.SECRETS_MASTER_KEY ?? process.env.SECRETS_KEY;
    if (!masterKey) {
      throw new Error("Missing SECRETS_MASTER_KEY environment variable");
    }
    const vaultFile = process.env.SECRETS_VAULT_FILE;
    const envFile = process.env.SECRETS_ENV_FILE ?? ".env";
    return new SecretsManager({ masterKey, vaultFile, envFile });
  }

  loadEnv(filePath: string): void {
    const env = parseEnvFile(filePath);
    for (const [key, value] of Object.entries(env)) {
      if (!(key in process.env)) {
        process.env[key] = value;
      }
    }
  }

  private encrypt(value: string): SecretPayload {
    const iv = randomBytes(12);
    const cipher = createCipheriv(algorithm, this.masterKey, iv);
    const encrypted = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
    const authTag = cipher.getAuthTag();
    return { iv: iv.toString("hex"), authTag: authTag.toString("hex"), value: encrypted.toString("hex") };
  }

  private decrypt(payload: SecretPayload): string {
    const decipher = createDecipheriv(algorithm, this.masterKey, Buffer.from(payload.iv, "hex"));
    decipher.setAuthTag(Buffer.from(payload.authTag, "hex"));
    const decrypted = Buffer.concat([decipher.update(Buffer.from(payload.value, "hex")), decipher.final()]);
    return decrypted.toString("utf8");
  }

  storeSecret(name: string, value: string): void {
    const encrypted = this.encrypt(value);
    this.vault[name] = encrypted;
    if (this.vaultFile) {
      writeFileSync(this.vaultFile, JSON.stringify(this.vault, null, 2));
    }
  }

  getSecret(name: string): string | undefined {
    const payload = this.vault[name];
    if (!payload) return undefined;
    return this.decrypt(payload);
  }

  getRuntimeSecret(name: string): string | undefined {
    return process.env[name] ?? this.getSecret(name);
  }
}
