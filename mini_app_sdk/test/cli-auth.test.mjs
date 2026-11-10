import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  computeHmacSha256,
  resolveCredentials,
  buildRequestHeaders,
} from '../dist/cli/utils/auth.js';
import { uploadProject } from '../dist/cli/commands/upload.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const sampleStoreDir = path.resolve(__dirname, '../../mini_apps/sample_store');

let savedEnv;

beforeEach(() => {
  savedEnv = { ...process.env };
  delete process.env.SUPERAPP_API_TOKEN;
  delete process.env.SUPERAPP_API_SECRET;
  delete process.env.SUPERAPP_TENANT_ID;
  delete process.env.SUPERAPP_ACTOR_ID;
});

afterEach(() => {
  process.env = savedEnv;
});

test('computeHmacSha256 produces valid SHA-256 HMAC hex string', () => {
  const secret = 'developer_secret_key_123';
  const data = 'timestamp_12345.{"version":"1.0.0"}';
  const hmac = computeHmacSha256(secret, data);

  assert.equal(typeof hmac, 'string');
  assert.equal(hmac.length, 64); // 256 bits = 64 hex characters
  // Identical input produces deterministic output
  assert.equal(computeHmacSha256(secret, data), hmac);
});

test('resolveCredentials prioritizes CLI options over environment and defaults', () => {
  process.env.SUPERAPP_API_TOKEN = 'env_token_456';
  process.env.SUPERAPP_API_SECRET = 'env_secret_789';

  const creds = resolveCredentials({
    token: 'cli_token_123',
    secret: 'cli_secret_abc',
    tenantId: 'custom_tenant',
    actorId: 'custom_actor',
  });

  assert.equal(creds.token, 'cli_token_123');
  assert.equal(creds.secret, 'cli_secret_abc');
  assert.equal(creds.tenantId, 'custom_tenant');
  assert.equal(creds.actorId, 'custom_actor');
});

test('resolveCredentials reads environment variables when CLI options are omitted', () => {
  process.env.SUPERAPP_API_TOKEN = 'env_token_456';
  process.env.SUPERAPP_API_SECRET = 'env_secret_789';
  process.env.SUPERAPP_TENANT_ID = 'env_tenant_999';

  const creds = resolveCredentials({});

  assert.equal(creds.token, 'env_token_456');
  assert.equal(creds.secret, 'env_secret_789');
  assert.equal(creds.tenantId, 'env_tenant_999');
});

test('buildRequestHeaders injects Authorization Bearer and HMAC signature', () => {
  const payload = { appId: 'my_app', version: '1.0.0' };
  const headers = buildRequestHeaders(
    {
      token: 'jwt_mock_token_xyz',
      secret: 'my_secret_key',
      tenantId: 'tenant_enterprise',
      actorId: 'developer_john',
    },
    payload
  );

  assert.equal(headers['Content-Type'], 'application/json');
  assert.equal(headers['Authorization'], 'Bearer jwt_mock_token_xyz');
  assert.equal(headers['x-tenant-id'], 'tenant_enterprise');
  assert.equal(headers['x-user-id'], 'developer_john');

  assert.ok(headers['x-signature-timestamp']);
  assert.ok(headers['x-signature'].startsWith('sha256='));

  // Verify signature validity
  const ts = headers['x-signature-timestamp'];
  const expectedHmac = computeHmacSha256('my_secret_key', `${ts}.${JSON.stringify(payload)}`);
  assert.equal(headers['x-signature'], `sha256=${expectedHmac}`);
});

test('buildRequestHeaders omits Authorization and Signature when credentials are not configured', () => {
  const headers = buildRequestHeaders({
    tenantId: 'tenant_001',
    actorId: 'dev_user',
  });

  assert.equal(headers['Authorization'], undefined);
  assert.equal(headers['x-signature'], undefined);
  assert.equal(headers['x-tenant-id'], 'tenant_001');
  assert.equal(headers['x-user-id'], 'dev_user');
});

test('uploadProject rejects remote registry upload when no authentication credentials are provided', async () => {
  await assert.rejects(
    uploadProject({
      registry: 'https://registry.superapp.vn',
      cwd: sampleStoreDir,
    }),
    err => err.message.includes('xác thực') || err.message.includes('Authentication required')
  );
});
