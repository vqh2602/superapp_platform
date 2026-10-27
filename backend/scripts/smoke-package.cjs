// Uses an isolated temporary PostgreSQL database and removes all test data on exit.
const { Client } = require('pg');
const { spawn } = require('node:child_process');
const { mkdtemp, rm, readFile, readdir } = require('node:fs/promises');
const { tmpdir } = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const root = path.resolve(__dirname, '..');
  const database = 'miniapp_package_check_' + Date.now();
  const storage = await mkdtemp(path.join(tmpdir(), 'miniapp-http-'));
  const port = process.env.SMOKE_PORT || '3037';
  const admin = new Client({ host: process.env.DB_HOST || 'localhost', port: Number(process.env.DB_PORT || 5432), user: process.env.DB_USERNAME || process.env.USER, password: process.env.DB_PASSWORD || '', database: 'postgres' });
  let server;
  let logs = '';
  let created = false;
  try {
    await admin.connect(); await admin.query(`CREATE DATABASE "${database}"`); created = true;
    server = spawn(process.execPath, ['dist/main.js'], { cwd: root, env: { ...process.env, DB_DATABASE: database, MINIAPP_STORAGE_DIR: storage, PORT: port }, stdio: ['ignore', 'pipe', 'pipe'] });
    server.stdout.on('data', value => logs += value); server.stderr.on('data', value => logs += value);
    const base = `http://localhost:${port}/api/v1/`;
    let ready = false;
    for (let attempt = 0; attempt < 100; attempt++) {
      try { if ((await fetch(base + 'registry/apps')).ok) { ready = true; break; } } catch {}
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    if (!ready) throw new Error(logs);
    const api = async (route, method = 'GET', body, status = 200) => {
      const form = body instanceof FormData;
      const response = await fetch(base + route, { method, ...(form ? {} : { headers: { 'Content-Type': 'application/json' } }), ...(body === undefined ? {} : { body: form ? body : JSON.stringify(body) }) });
      const text = await response.text();
      assert.equal(response.status, status, `${route}: ${text}`);
      return response.headers.get('content-type')?.includes('json') ? JSON.parse(text) : text;
    };
    const form = buffer => { const value = new FormData(); value.append('file', new Blob([buffer]), 'miniapp.zip'); value.append('notes', 'Package smoke release'); return value; };
    for (const runtime of ['web', 'schema']) {
      const appId = `${runtime}_demo`;
      const archive = await readFile(path.join(root, '../builder/public/examples', `${runtime}-demo.zip`));
      await api('registry/apps', 'POST', { id: appId, name: 'Temporary', runtimeType: runtime }, 201);
      const inspected = await api(`registry/apps/${appId}/packages/inspect`, 'POST', form(archive), 201);
      assert.equal(inspected.manifest.appId, appId);
      await api(`registry/apps/${appId}/versions`, 'POST', form(archive), 201);
      await api(`registry/apps/${appId}/versions`, 'POST', form(archive), 409);
      await api(`catalog/apps/${appId}`, 'GET', undefined, 403);
      const icon = await fetch(base + `miniapps/${appId}/1.0.0/icon.png`);
      assert.equal(icon.status, 200); assert.match(icon.headers.get('content-type'), /image\/png/);
      if (runtime === 'web') await api(`miniapps/${appId}/1.0.0/dist/index.html`, 'GET', undefined, 403);
      await api(`registry/apps/${appId}/visibility`, 'PATCH', { visible: true });
      let manifest = await api(`catalog/apps/${appId}`);
      assert.deepEqual(manifest.capabilities, []);
      assert.deepEqual(manifest.requestedPermissions, ['navigation.close']);
      await api(`registry/apps/${appId}`, 'PUT', { capabilities: ['payment.createOrder'] }, 400);
      await api(`registry/apps/${appId}`, 'PUT', { capabilities: ['navigation.close'], name: 'Managed name', developerName: 'Demo team' });
      manifest = await api(`catalog/apps/${appId}`);
      assert.deepEqual(manifest.capabilities, ['navigation.close']); assert.equal(manifest.name, 'Managed name');
      if (runtime === 'web') {
        assert.match(await api('miniapps/web_demo/1.0.0/dist/index.html'), /Web Mini App/);
        assert.match(await api('miniapps/web_demo/1.0.0/dist/assets/app.js'), /navigation.close/);
        const css = await fetch(base + 'miniapps/web_demo/1.0.0/dist/assets/style.css');
        assert.match(css.headers.get('content-type'), /text\/css/);
        await api('registry/apps/schema_demo/versions', 'POST', form(archive), 400);
      } else assert.equal(manifest.schema.pages[0].id, 'home');
      const detail = await api(`registry/apps/${appId}`);
      assert.equal(detail.versions.length, 1); assert.match(detail.versions[0].checksum, /^[a-f0-9]{64}$/);
      await api(`registry/apps/${appId}/visibility`, 'PATCH', { visible: false });
      await api(`catalog/apps/${appId}`, 'GET', undefined, 403);
      if (runtime === 'web') await api(`miniapps/${appId}/1.0.0/dist/assets/app.js`, 'GET', undefined, 403);
    }
    assert.equal((await readdir(storage)).length, 2);
    console.log('PostgreSQL package smoke passed: web/schema ZIP inspection, upload, duplicate rejection, manifest metadata, explicit grants, icon/HTML/JS/CSS serving, show/hide and direct-launch blocking.');
  } finally {
    if (server && server.exitCode === null) { server.kill('SIGTERM'); await new Promise(resolve => server.once('exit', resolve)); }
    if (created) await admin.query(`DROP DATABASE "${database}" WITH (FORCE)`);
    await admin.end(); await rm(storage, { recursive: true, force: true });
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
