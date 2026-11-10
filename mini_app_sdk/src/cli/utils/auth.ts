import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export interface DeveloperCredentials {
  token?: string;
  secret?: string;
  tenantId?: string;
  actorId?: string;
}

export function computeHmacSha256(secret: string, data: string): string {
  return crypto.createHmac('sha256', secret).update(data).digest('hex');
}

/**
 * Searches for locally stored developer credentials in standard CLI paths:
 * 1. Current working directory: .superapprc, .superapp/credentials.json
 * 2. User home directory: ~/.superapp/credentials.json, ~/.superapprc
 */
export function loadStoredCredentials(cwd: string = process.cwd()): DeveloperCredentials {
  const candidates = [
    path.join(cwd, '.superapprc'),
    path.join(cwd, '.superapp', 'credentials.json'),
    path.join(os.homedir(), '.superapp', 'credentials.json'),
    path.join(os.homedir(), '.superapprc'),
  ];

  for (const filePath of candidates) {
    if (fs.existsSync(filePath)) {
      try {
        const raw = fs.readFileSync(filePath, 'utf-8');
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object') {
          return {
            token: parsed.token || parsed.apiToken || parsed.accessToken,
            secret: parsed.secret || parsed.apiSecret,
            tenantId: parsed.tenantId,
            actorId: parsed.actorId || parsed.userId,
          };
        }
      } catch (_) {}
    }
  }

  return {};
}

/**
 * Resolves developer credentials with priority:
 * 1. CLI explicit options
 * 2. Environment variables (SUPERAPP_API_TOKEN, SUPERAPP_API_SECRET, etc.)
 * 3. Stored credentials file (~/.superapp/credentials.json)
 * 4. Default fallback identifiers for local sandbox
 */
export function resolveCredentials(cliOptions: {
  token?: string;
  secret?: string;
  tenantId?: string;
  actorId?: string;
} = {}): DeveloperCredentials {
  const fileCreds = loadStoredCredentials();

  const token =
    cliOptions.token ||
    process.env.SUPERAPP_API_TOKEN ||
    process.env.SUPERAPP_DEVELOPER_TOKEN ||
    process.env.SUPERAPP_AUTH_TOKEN ||
    fileCreds.token;

  const secret =
    cliOptions.secret ||
    process.env.SUPERAPP_API_SECRET ||
    fileCreds.secret;

  const tenantId =
    cliOptions.tenantId ||
    process.env.SUPERAPP_TENANT_ID ||
    fileCreds.tenantId ||
    'tenant_001';

  const actorId =
    cliOptions.actorId ||
    process.env.SUPERAPP_ACTOR_ID ||
    process.env.SUPERAPP_USER_ID ||
    fileCreds.actorId ||
    'dev_partner_001';

  return { token, secret, tenantId, actorId };
}

/**
 * Builds standard secure headers for registry HTTP requests:
 * - Authorization: Bearer <token> (JWT / OAuth token)
 * - x-signature & x-signature-timestamp: HMAC-SHA256 signature for payload integrity
 * - Contextual x-tenant-id and x-user-id
 */
export function buildRequestHeaders(
  credentials: DeveloperCredentials,
  payload?: any,
  additionalHeaders: Record<string, string> = {}
): Record<string, string> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...additionalHeaders,
  };

  // 1. Bearer Token Authentication
  if (credentials.token) {
    headers['Authorization'] = `Bearer ${credentials.token}`;
  }

  // 2. Cryptographic signature (HMAC-SHA256)
  if (credentials.secret) {
    const timestamp = Date.now().toString();
    const payloadStr = payload ? (typeof payload === 'string' ? payload : JSON.stringify(payload)) : '';
    const signature = computeHmacSha256(credentials.secret, `${timestamp}.${payloadStr}`);
    headers['x-signature-timestamp'] = timestamp;
    headers['x-signature'] = `sha256=${signature}`;
  }

  // 3. Contextual identifiers
  if (credentials.tenantId) {
    headers['x-tenant-id'] = credentials.tenantId;
  }
  if (credentials.actorId) {
    headers['x-user-id'] = credentials.actorId;
  }

  return headers;
}

