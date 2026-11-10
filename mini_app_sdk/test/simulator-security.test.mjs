import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  isAllowedCorsOrigin,
  isAllowedMiniAppUrl,
  startSimulatorServer,
} from '../dist/cli/utils/server.js';

test('isAllowedCorsOrigin allows local loopback and rejects remote origins', () => {
  // Allowed
  assert.equal(isAllowedCorsOrigin('http://localhost:3000'), true);
  assert.equal(isAllowedCorsOrigin('http://localhost:5173'), true);
  assert.equal(isAllowedCorsOrigin('http://127.0.0.1:3000'), true);
  assert.equal(isAllowedCorsOrigin('http://sub.localhost:8080'), true);

  // Rejected
  assert.equal(isAllowedCorsOrigin('https://evil-attacker.com'), false);
  assert.equal(isAllowedCorsOrigin('http://192.168.1.100:3000'), false);
  assert.equal(isAllowedCorsOrigin('javascript:alert(1)'), false);
  assert.equal(isAllowedCorsOrigin('null'), false);
  assert.equal(isAllowedCorsOrigin(''), false);
});

test('isAllowedMiniAppUrl enforces safe schemes, localhost HTTP, and blocks dangerous schemes', () => {
  // Allowed
  assert.equal(isAllowedMiniAppUrl('http://localhost:3000'), true);
  assert.equal(isAllowedMiniAppUrl('http://127.0.0.1:5173/app'), true);
  assert.equal(isAllowedMiniAppUrl('https://demo.superapp.vn/mini-app'), true);
  assert.equal(isAllowedMiniAppUrl('https://my-store.apps.example.com'), true);

  // Rejected: dangerous schemes
  assert.equal(isAllowedMiniAppUrl('javascript:alert(1)'), false);
  assert.equal(isAllowedMiniAppUrl('data:text/html,<script>alert(1)</script>'), false);
  assert.equal(isAllowedMiniAppUrl('file:///etc/passwd'), false);
  assert.equal(isAllowedMiniAppUrl('blob:http://localhost:3000/123'), false);

  // Rejected: plain HTTP over public network (unencrypted)
  assert.equal(isAllowedMiniAppUrl('http://evil-attacker.com/app'), false);
  assert.equal(isAllowedMiniAppUrl('http://10.0.0.5:3000'), false);

  // Rejected: embedded credentials
  assert.equal(isAllowedMiniAppUrl('http://user:pass@localhost:3000'), false);
});

test('startSimulatorServer binds strictly to 127.0.0.1 and sets security headers with restricted CORS', async () => {
  const testPort = 5988;
  const server = startSimulatorServer(testPort, '127.0.0.1');

  try {
    // Wait for server to bind
    await new Promise((resolve) => {
      if (server.listening) resolve();
      else server.once('listening', resolve);
    });

    const addr = server.address();
    assert.ok(addr && typeof addr === 'object');
    assert.equal(addr.address, '127.0.0.1'); // Bound strictly to loopback!

    // 1. Request with allowed local origin
    const resAllowed = await fetch(`http://127.0.0.1:${testPort}/`, {
      headers: { Origin: 'http://localhost:3000' },
    });
    assert.equal(resAllowed.headers.get('access-control-allow-origin'), 'http://localhost:3000');
    assert.equal(resAllowed.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(resAllowed.headers.get('x-frame-options'), 'SAMEORIGIN');

    // 2. Request with untrusted origin (e.g. malicious site)
    const resBlocked = await fetch(`http://127.0.0.1:${testPort}/`, {
      headers: { Origin: 'https://evil-attacker.com' },
    });
    // Must NOT reflect untrusted origin and must NOT be '*'
    assert.notEqual(resBlocked.headers.get('access-control-allow-origin'), 'https://evil-attacker.com');
    assert.notEqual(resBlocked.headers.get('access-control-allow-origin'), '*');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
