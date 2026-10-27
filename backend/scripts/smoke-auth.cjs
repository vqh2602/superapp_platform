// Real PostgreSQL/HTTP integration checks; all accounts, apps and tokens are disposable.
const { Client } = require('pg');
const { spawn } = require('node:child_process');
const { randomBytes, createHash } = require('node:crypto');
const { mkdtemp, rm } = require('node:fs/promises');
const { tmpdir } = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { makePackage, testManifest } = require('../dist/modules/registry/packages/test-package');

(async () => {
  const root = path.resolve(__dirname, '..');
  const database = 'miniapp_auth_check_' + Date.now();
  const storage = await mkdtemp(path.join(tmpdir(), 'miniapp-auth-'));
  const port = process.env.SMOKE_PORT || '3039';
  const config = { host: process.env.DB_HOST || 'localhost', port: Number(process.env.DB_PORT || 5432), user: process.env.DB_USERNAME || process.env.USER, password: process.env.DB_PASSWORD || '' };
  const admin = new Client({ ...config, database: 'postgres' });
  let data;
  let server;
  let created = false;
  let assertions = 0;
  const base = `http://localhost:${port}/api/v1/`;
  async function stop() {
    if (server && server.exitCode === null) { server.kill('SIGTERM'); await new Promise(resolve => server.once('exit', resolve)); }
  }
  async function start() {
    let logs = '';
    server = spawn(process.execPath, ['dist/main.js'], { cwd: root, env: { ...process.env, DB_DATABASE: database, MINIAPP_STORAGE_DIR: storage, PORT: port }, stdio: ['ignore', 'pipe', 'pipe'] });
    server.stdout.on('data', chunk => logs += chunk); server.stderr.on('data', chunk => logs += chunk);
    for (let attempt = 0; attempt < 100; attempt++) {
      try { if ((await fetch(base + 'registry/apps')).ok) return; } catch {}
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    throw new Error(logs);
  }
  async function api(route, method = 'GET', body, token, status = 200) {
    const response = await fetch(base + route, { method, headers: { ...(body instanceof FormData ? {} : { 'Content-Type': 'application/json' }), ...(token ? { Authorization: `Bearer ${token}` } : {}) }, ...(body === undefined ? {} : { body: body instanceof FormData ? body : JSON.stringify(body) }) });
    const result = await response.json();
    assert.equal(response.status, status, `${route}: ${JSON.stringify(result)}`); assertions++;
    return result;
  }
  const hash = value => createHash('sha256').update(value).digest('hex');
  const verifier = () => randomBytes(32).toString('base64url');
  const challenge = value => createHash('sha256').update(value).digest('base64url');
  async function code(token, scopes = ['user.getBasicInfo'], appId = 'auth_demo') {
    const codeVerifier = verifier();
    const result = await api('miniapp/auth/code', 'POST', { appId, scopes, codeChallenge: challenge(codeVerifier), codeChallengeMethod: 'S256' }, token, 201);
    return { appId, authCode: result.authCode, codeVerifier };
  }
  try {
    await admin.connect(); await admin.query(`CREATE DATABASE "${database}"`); created = true;
    data = new Client({ ...config, database }); await data.connect();
    await start();
    for (const appId of ['auth_demo', 'other_demo']) {
      await api('registry/apps', 'POST', { id: appId, name: appId, runtimeType: 'web' }, undefined, 201);
      const zip = await makePackage({ ...testManifest, appId, permissions: ['user.getBasicInfo', 'user.getProfile', 'navigation.close'] });
      const form = new FormData(); form.append('file', new Blob([zip]), 'miniapp.zip');
      await api(`registry/apps/${appId}/versions`, 'POST', form, undefined, 201);
      await api(`registry/apps/${appId}`, 'PUT', { capabilities: ['user.getBasicInfo', 'user.getProfile', 'navigation.close'] });
      await api(`registry/apps/${appId}/visibility`, 'PATCH', { visible: true });
    }
    await api('auth/me', 'GET', undefined, undefined, 401);
    let alice = await api('auth/register', 'POST', { email: ' Alice@Example.com ', password: 'demo-password-123', displayName: 'Alice' }, undefined, 201);
    const bob = await api('auth/register', 'POST', { email: 'bob@example.com', password: 'demo-password-456', displayName: 'Bob' }, undefined, 201);
    assert.equal(alice.user.email, 'alice@example.com'); assert.equal(alice.user.passwordHash, undefined);
    assert.match(alice.accessToken, /^access_[A-Za-z0-9_-]{43}$/);
    await api('auth/register', 'POST', { email: 'alice@example.com', password: 'another-password', displayName: 'Duplicate' }, undefined, 409);
    await api('auth/register', 'POST', { email: 'short@example.com', password: 'short', displayName: 'Short' }, undefined, 400);
    await api('auth/register', 'POST', { email: 'role@example.com', password: 'long-password', displayName: 'Role', role: 'admin' }, undefined, 400);
    await api('auth/login', 'POST', { email: 'alice@example.com', password: 'wrong-password' }, undefined, 401);
    await api('auth/login', 'POST', { email: 'unknown@example.com', password: 'wrong-password' }, undefined, 401);
    const aliceSecond = await api('auth/login', 'POST', { email: 'ALICE@example.com', password: 'demo-password-123' });
    const profile = await api('auth/me', 'PATCH', { displayName: 'Alice Updated', avatarUrl: 'https://example.com/avatar.png' }, alice.accessToken);
    assert.equal(profile.displayName, 'Alice Updated');
    await api('auth/me', 'PATCH', {}, alice.accessToken, 400);
    const launch = await api('miniapp/apps/auth_demo/launch-context', 'GET', undefined, alice.accessToken);
    assert.deepEqual(launch.effectivePermissions, []);
    await api('miniapp/auth/code', 'POST', { appId: 'auth_demo', scopes: ['user.getBasicInfo'], codeChallenge: challenge(verifier()), codeChallengeMethod: 'S256' }, alice.accessToken, 403);
    await api('users/me/apps/auth_demo/permissions', 'PUT', { permissions: ['user.getBasicInfo', 'navigation.close'], granted: true }, alice.accessToken);
    await api('users/me/apps/auth_demo/permissions', 'PUT', { permissions: ['device.getLocation'], granted: true }, alice.accessToken, 400);
    await api('users/me/apps/auth_demo/permissions', 'PUT', { permissions: [], granted: true, userId: bob.user.id }, alice.accessToken, 400);
    assert.deepEqual((await api('users/me/apps/auth_demo/permissions', 'GET', undefined, bob.accessToken)).userPermissions, []);
    assert.equal((await api('users/me/apps', 'GET', undefined, alice.accessToken))[0].appId, 'auth_demo');
    const firstCode = await code(alice.accessToken);
    await api('miniapp/auth/token', 'POST', { ...firstCode, appId: 'other_demo' }, undefined, 401);
    await api('miniapp/auth/token', 'POST', { ...firstCode, codeVerifier: verifier() }, undefined, 401);
    let mini = await api('miniapp/auth/token', 'POST', firstCode);
    assert.equal(mini.audience, 'miniapp'); assert.equal(mini.appId, 'auth_demo');
    await api('miniapp/auth/token', 'POST', firstCode, undefined, 401);
    const miniProfile = await api('miniapp/me', 'GET', undefined, mini.accessToken);
    assert.equal(miniProfile.name, 'Alice Updated'); assert.equal(miniProfile.email, undefined); assert.equal(miniProfile.id, undefined);
    await api('auth/me', 'GET', undefined, mini.accessToken, 403);
    await api('users/me/apps', 'GET', undefined, mini.accessToken, 403);
    await api('users/me/apps/auth_demo/permissions', 'PUT', { permissions: ['user.getProfile'], granted: true }, mini.accessToken, 403);
    await api('miniapp/auth/code', 'POST', { appId: 'other_demo', codeChallenge: challenge(verifier()), codeChallengeMethod: 'S256' }, mini.accessToken, 403);
    await api('miniapp/apps/other_demo/launch-context', 'GET', undefined, mini.accessToken, 403);
    await api('miniapp/me', 'GET', undefined, alice.accessToken, 403);
    await api('users/me/apps/other_demo/permissions', 'PUT', { permissions: ['user.getBasicInfo'], granted: true }, alice.accessToken);
    const other = await api('miniapp/auth/token', 'POST', await code(alice.accessToken, ['user.getBasicInfo'], 'other_demo'));
    assert.notEqual(other.openId, mini.openId);
    await api('users/me/apps/auth_demo/permissions', 'PUT', { permissions: ['user.getBasicInfo'], granted: false }, alice.accessToken);
    await api('miniapp/me', 'GET', undefined, mini.accessToken, 403);
    assert.deepEqual((await api('miniapp/permissions', 'GET', undefined, mini.accessToken)).effectivePermissions, []);
    await api('users/me/apps/auth_demo/permissions', 'PUT', { permissions: ['user.getBasicInfo', 'user.getProfile'], granted: true }, alice.accessToken);
    assert.equal((await api('miniapp/me', 'GET', undefined, mini.accessToken)).email, undefined);
    const full = await api('miniapp/auth/token', 'POST', await code(alice.accessToken, ['user.getProfile']));
    assert.equal((await api('miniapp/me', 'GET', undefined, full.accessToken)).email, 'alice@example.com');
    await api('users/me/apps/auth_demo/permissions', 'PUT', { permissions: ['user.getProfile'], granted: false }, alice.accessToken);
    await api('miniapp/me', 'GET', undefined, full.accessToken, 403);
    await api('registry/apps/auth_demo', 'PUT', { capabilities: ['navigation.close', 'user.getProfile'] });
    await api('miniapp/me', 'GET', undefined, mini.accessToken, 403);
    await api('registry/apps/auth_demo', 'PUT', { capabilities: ['navigation.close', 'user.getBasicInfo', 'user.getProfile'] });
    const oldMini = mini;
    mini = await api('auth/refresh', 'POST', { refreshToken: mini.refreshToken });
    assert.equal(mini.audience, 'miniapp'); assert.equal(mini.appId, 'auth_demo');
    await api('miniapp/me', 'GET', undefined, oldMini.accessToken, 401);
    await api('auth/refresh', 'POST', { refreshToken: oldMini.refreshToken }, undefined, 401);
    await api('miniapp/me', 'GET', undefined, mini.accessToken);
    const racingCode = await code(alice.accessToken);
    const race = await Promise.all([1, 2].map(() => fetch(base + 'miniapp/auth/token', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(racingCode) })));
    assert.deepEqual(race.map(result => result.status).sort(), [200, 401]); assertions++;
    const expiringCode = await code(alice.accessToken);
    await data.query('UPDATE miniapp_auth_codes SET "expiresAt" = NOW() - interval \'1 second\' WHERE "codeHash" = $1', [hash(expiringCode.authCode)]);
    await api('miniapp/auth/token', 'POST', expiringCode, undefined, 401);
    const changedCode = await code(alice.accessToken);
    await api('users/me/apps/auth_demo/permissions', 'DELETE', undefined, alice.accessToken);
    await api('miniapp/auth/token', 'POST', changedCode, undefined, 403);
    assert.deepEqual((await api('users/me/apps/auth_demo/permissions', 'GET', undefined, alice.accessToken)).effectivePermissions, []);
    await api('users/me/apps/auth_demo/permissions', 'PUT', { permissions: ['user.getBasicInfo'], granted: true }, alice.accessToken);
    const concurrentRefresh = await Promise.all([1, 2].map(() => fetch(base + 'auth/refresh', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: mini.refreshToken }) })));
    assert.deepEqual(concurrentRefresh.map(result => result.status).sort(), [200, 401]); assertions++;
    mini = await concurrentRefresh.find(result => result.status === 200).json();
    const oldAlice = alice;
    alice = { user: alice.user, ...await api('auth/refresh', 'POST', { refreshToken: alice.refreshToken }) };
    await api('auth/me', 'GET', undefined, oldAlice.accessToken, 401);
    await api('auth/refresh', 'POST', { refreshToken: oldAlice.refreshToken }, undefined, 401);
    await api('miniapp/me', 'GET', undefined, mini.accessToken);
    const stored = await data.query('SELECT "passwordHash" FROM users WHERE id = $1', [alice.user.id]);
    assert.match(stored.rows[0].passwordHash, /^scrypt\$/); assert.notEqual(stored.rows[0].passwordHash, 'demo-password-123');
    const hashes = await data.query('SELECT "accessTokenHash", "refreshTokenHash" FROM auth_sessions WHERE "accessTokenHash" = $1', [hash(alice.accessToken)]);
    assert.equal(hashes.rows[0].accessTokenHash, hash(alice.accessToken)); assert.notEqual(hashes.rows[0].refreshTokenHash, alice.refreshToken);
    await stop(); await start();
    await api('auth/me', 'GET', undefined, bob.accessToken);
    assert.deepEqual((await api('users/me/apps/auth_demo/permissions', 'GET', undefined, alice.accessToken)).effectivePermissions, ['user.getBasicInfo']);
    const logoutCode = await code(alice.accessToken);
    await api('auth/logout', 'POST', undefined, alice.accessToken);
    await api('miniapp/auth/token', 'POST', logoutCode, undefined, 401);
    await api('miniapp/me', 'GET', undefined, mini.accessToken, 401);
    await api('auth/refresh', 'POST', { refreshToken: alice.refreshToken }, undefined, 401);
    await api('auth/me', 'GET', undefined, aliceSecond.accessToken);
    await api('auth/logout-all', 'POST', undefined, aliceSecond.accessToken);
    await api('auth/me', 'GET', undefined, aliceSecond.accessToken, 401);
    await api('auth/me', 'GET', undefined, bob.accessToken);
    await data.query('UPDATE auth_sessions SET "expiresAt" = NOW() - interval \'1 second\' WHERE "accessTokenHash" = $1', [hash(bob.accessToken)]);
    await api('auth/me', 'GET', undefined, bob.accessToken, 401);
    await data.query('UPDATE auth_sessions SET "refreshExpiresAt" = NOW() - interval \'1 second\' WHERE "refreshTokenHash" = $1', [hash(bob.refreshToken)]);
    await api('auth/refresh', 'POST', { refreshToken: bob.refreshToken }, undefined, 401);
    let limited;
    for (let i = 0; i < 11; i++) limited = await fetch(base + 'auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: 'no-user@example.com', password: 'incorrect-password' }) });
    assert.equal(limited.status, 429); assert.ok(Number(limited.headers.get('retry-after')) > 0); assertions++;
    console.log(`PostgreSQL auth smoke passed: ${assertions} HTTP/concurrency checks; account registration/login, hashed credentials/tokens, PKCE single use/expiry, token rotation, user/app isolation, live grant revocation, restart persistence, logout and rate limiting.`);
  } finally {
    await stop(); if (data) await data.end();
    if (created) await admin.query(`DROP DATABASE "${database}" WITH (FORCE)`);
    await admin.end(); await rm(storage, { recursive: true, force: true });
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
