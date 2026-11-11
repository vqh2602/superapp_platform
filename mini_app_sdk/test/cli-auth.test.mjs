import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  computeHmacSha256,
  resolveCredentials,
  buildRequestHeaders,
} from '../dist/cli/utils/auth.js';
import {
  uploadProject,
  validateRegistryUrl,
  isLoopbackHostname,
} from '../dist/cli/commands/upload.js';

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

test('isLoopbackHostname only allows exact loopback hostnames and blocks deceptive domains', () => {
  // Loopback hợp lệ
  assert.equal(isLoopbackHostname('localhost'), true);
  assert.equal(isLoopbackHostname('127.0.0.1'), true);
  assert.equal(isLoopbackHostname('[::1]'), true);
  assert.equal(isLoopbackHostname('::1'), true);
  assert.equal(isLoopbackHostname('LOCALHOST'), true);

  // Hostname giả mạo / lừa đảo (deceptive hostnames)
  assert.equal(isLoopbackHostname('localhost.evil.example'), false);
  assert.equal(isLoopbackHostname('localhost-evil.com'), false);
  assert.equal(isLoopbackHostname('127.0.0.1.attacker.com'), false);
  assert.equal(isLoopbackHostname('evil.com'), false);
  assert.equal(isLoopbackHostname('sub.localhost'), false);
});

test('validateRegistryUrl enforces HTTPS for remote registries and allows HTTP only for loopback', () => {
  // 1. Cho phép loopback HTTP
  const local1 = validateRegistryUrl('http://localhost:3000');
  assert.equal(local1.isLocal, true);
  assert.equal(local1.url.origin, 'http://localhost:3000');

  const local2 = validateRegistryUrl('http://127.0.0.1:8080/api');
  assert.equal(local2.isLocal, true);

  const local3 = validateRegistryUrl('http://[::1]:3000');
  assert.equal(local3.isLocal, true);

  // 2. Cho phép HTTPS cho cả remote và local
  const remoteHttps = validateRegistryUrl('https://registry.superapp.vn');
  assert.equal(remoteHttps.isLocal, false);
  assert.equal(remoteHttps.url.origin, 'https://registry.superapp.vn');

  // 3. Chặn đứng HTTP đối với remote registry (chống lộ token qua plaintext HTTP)
  assert.throws(
    () => validateRegistryUrl('http://remote-registry.example.com'),
    err => err.message.includes('bắt buộc phải sử dụng giao thức HTTPS')
  );

  // 4. Chặn đứng hostname giả mạo localhost chạy HTTP
  assert.throws(
    () => validateRegistryUrl('http://localhost.evil.example:3000'),
    err => err.message.includes('bắt buộc phải sử dụng giao thức HTTPS')
  );

  assert.throws(
    () => validateRegistryUrl('http://127.0.0.1.attacker.com:3000'),
    err => err.message.includes('bắt buộc phải sử dụng giao thức HTTPS')
  );

  // 5. Chặn giao thức không an toàn khác (ftp, javascript, etc.)
  assert.throws(
    () => validateRegistryUrl('ftp://localhost:21'),
    err => err.message.includes('không được hỗ trợ')
  );

  // 6. Chặn URL malformed
  assert.throws(
    () => validateRegistryUrl('invalid://url::bad'),
    err => err.message.includes('không hợp lệ')
  );
});

test('uploadProject refuses to send developer token over unencrypted HTTP to remote or deceptive hostnames', async () => {
  // Dù có cung cấp token, CLI vẫn từ chối gửi token qua HTTP không mã hóa đến remote host
  await assert.rejects(
    uploadProject({
      registry: 'http://remote-registry.example.com',
      token: 'dev_secret_jwt_token',
      cwd: sampleStoreDir,
    }),
    err => err.message.includes('bắt buộc phải sử dụng giao thức HTTPS')
  );

  // Chặn gửi token tới hostname lừa đảo localhost.evil.example
  await assert.rejects(
    uploadProject({
      registry: 'http://localhost.evil.example',
      token: 'dev_secret_jwt_token',
      cwd: sampleStoreDir,
    }),
    err => err.message.includes('bắt buộc phải sử dụng giao thức HTTPS')
  );
});
