import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
import { SuperAppSDK, TransportResolver } from '../dist/index.js';
import { NativeBridgeTransport } from '../dist/transport/native-transport.js';

const legacySource = fs.readFileSync(new URL('../../mini_apps/sdk_playground/src/sdk/bridgeTransport.ts', import.meta.url), 'utf8');
const legacyJs = ts.transpileModule(legacySource, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
let win;
let requests;
function attachHost() {
  win.FlutterBridge = { postMessage(raw) {
    const req = JSON.parse(raw);
    requests.push(req);
    win.SuperAppBridge.dispatchResponse({ id: req.id, success: true, data: { action: req.action, appId: req.appId } });
  } };
}
function legacyClient() {
  const exports = {};
  vm.runInNewContext(legacyJs, { exports, require: () => ({ TransportResolver }), window: win, console, setTimeout, clearTimeout });
  return new exports.BridgeTransport('sdk_playground');
}
beforeEach(() => {
  requests = [];
  win = { location: { origin: 'https://miniapp.test' }, addEventListener() {}, removeEventListener() {} };
  win.parent = win;
  globalThis.window = win;
});
afterEach(() => { delete globalThis.window; });

test('SDK initialized first delivers responses to Playground and plain JS callbacks', async () => {
  attachHost();
  const sdk = new SuperAppSDK({ appId: 'sdk_playground' });
  const legacy = legacyClient();
  assert.deepEqual(JSON.parse(JSON.stringify(await legacy.invoke('user.getProfile', {}, 50))), { action: 'user.getProfile', appId: 'sdk_playground' });
  let direct;
  win.SuperAppBridge._callbacks.direct = response => { direct = response.data; };
  win.SuperAppBridge.dispatchResponse({ id: 'direct', success: true, data: 'plain-js-ok' });
  assert.equal(direct, 'plain-js-ok');
  assert.equal(await sdk.transport.invoke('debug.echo').then(r => r.action), 'debug.echo');
  assert.deepEqual(Object.keys(win.SuperAppBridge._callbacks), []);
});

test('Playground initialized first coexists with multiple official SDK instances', async () => {
  attachHost();
  const legacy = legacyClient();
  const first = new SuperAppSDK({ appId: 'first' });
  const second = new SuperAppSDK({ appId: 'second' });
  const values = await Promise.all([
    first.transport.invoke('user.getProfile'), second.transport.invoke('getSystemInfo'), legacy.invoke('user.getBasicInfo', {}, 50),
  ]);
  assert.deepEqual(values.map(v => v.appId), ['first', 'second', 'sdk_playground']);
  assert.equal(new Set(requests.map(r => r.id)).size, 3);
  const dispatcher = win.SuperAppBridge.dispatchResponse;
  await first.transport.invoke('debug.echo');
  assert.equal(win.SuperAppBridge.dispatchResponse, dispatcher);
});

test('shared events reach both SDK and direct JS listeners once', async () => {
  attachHost();
  const first = new SuperAppSDK();
  const second = new SuperAppSDK();
  const legacy = legacyClient();
  const hits = [0, 0, 0];
  const off = first.on('miniapp.ready', () => hits[0]++);
  second.on('miniapp.ready', () => hits[1]++);
  legacy.addEventListener('miniapp.ready', () => hits[2]++);
  await first.transport.invoke('debug.echo');
  await first.transport.invoke('debug.echo');
  win.SuperAppBridge.dispatchEvent({ event: 'miniapp.ready', payload: {} });
  assert.deepEqual(hits, [1, 1, 1]);
  off();
  win.SuperAppBridge.dispatchEvent({ event: 'miniapp.ready', payload: {} });
  assert.deepEqual(hits, [1, 2, 2]);
});

test('standalone browser rejects calls instead of returning synthetic data', async () => {
  const sdk = new SuperAppSDK();
  assert.equal(sdk.transport.getType(), 'unavailable');
  assert.equal(sdk.transport.isConnected(), false);
  await assert.rejects(sdk.transport.invoke('user.getProfile'), error => error.code === 'NATIVE_NOT_AVAILABLE');
  assert.deepEqual(requests, []);
});

test('iframe uses simulator transport when no native channel is present', async () => {
  let posted;
  win.parent = { postMessage(message) { posted = message; } };
  const sdk = new SuperAppSDK({ timeoutMs: 10 });
  assert.equal(sdk.transport.getType(), 'postmessage');
  await assert.rejects(sdk.transport.invoke('debug.echo'), error => error.code === 'TIMEOUT');
  assert.equal(posted.type, 'SUPERAPP_BRIDGE_REQUEST');
});

test('native channel attaching after import is detected dynamically', async () => {
  const sdk = new SuperAppSDK({ appId: 'late' });
  assert.equal(sdk.transport.getType(), 'unavailable');
  attachHost();
  assert.equal(sdk.transport.getType(), 'native');
  assert.deepEqual(await sdk.transport.invoke('user.getProfile'), { action: 'user.getProfile', appId: 'late' });
});

test('native errors and timeouts clean up pending global callbacks', async () => {
  attachHost();
  const sdk = new SuperAppSDK({ timeoutMs: 10 });
  win.FlutterBridge.postMessage = raw => {
    const req = JSON.parse(raw);
    win.SuperAppBridge.dispatchResponse({ id: req.id, success: false, error: { code: 'AUTH_REQUIRED' } });
  };
  await assert.rejects(sdk.transport.invoke('user.getProfile'), error => error.code === 'AUTH_REQUIRED');
  win.FlutterBridge.postMessage = () => {};
  await assert.rejects(sdk.transport.invoke('user.getProfile'), error => error.code === 'TIMEOUT');
  assert.deepEqual(Object.keys(win.SuperAppBridge._callbacks), []);
});

test('forced native without a host rejects immediately', async () => {
  const native = new NativeBridgeTransport({ timeoutMs: 10 });
  assert.equal(native.isConnected(), false);
  await assert.rejects(native.invoke('user.getProfile'), error => error.code === 'NATIVE_NOT_AVAILABLE');
});

const flutterHostPolyfill = fs.readFileSync(new URL('../../lib/features/mini_app_bridge/bridge_channel.dart', import.meta.url), 'utf8')
  .match(/bridgePolyfillScript = '''([\s\S]*?)'''/)[1];
for (const order of ['host-first', 'sdk-first']) {
  test(`actual Flutter host polyfill interoperates with SDK and Playground (${order})`, async () => {
    attachHost();
    const injectHost = () => vm.runInNewContext(flutterHostPolyfill, { window: win, console, setTimeout, clearTimeout });
    if (order === 'host-first') injectHost();
    const sdk = new SuperAppSDK({ appId: 'sdk_playground', timeoutMs: 50 });
    if (order === 'sdk-first') injectHost();
    const playground = legacyClient();
    assert.equal((await sdk.getUserProfile()).action, 'auth.getUserProfile');
    assert.equal((await playground.invoke('user.getProfile', {}, 50)).action, 'user.getProfile');
    // Host's raw-JS API must continue resolving its own callback registry.
    assert.equal((await win.bridge.invoke('user.getProfile')).action, 'user.getProfile');
    assert.deepEqual(Object.keys(win.SuperAppBridge._callbacks), []);
  });
}

const { INTERACTIVE_BRIDGE_ACTIONS, bridgeTimeoutMs } = await import('../dist/transport/timeout-policy.js');
const { PostMessageTransport } = await import('../dist/transport/postmessage-transport.js');
test('camera/QR native calls still resolve after the previous 10s deadline', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  let request;
  win.FlutterBridge = { postMessage(raw) { request = JSON.parse(raw); } };
  const transport = new NativeBridgeTransport();
  for (const action of ['device.scanQRCode', 'scanQr', 'getPhoto', 'device.pickImage']) {
    const pending = transport.invoke(action);
    t.mock.timers.tick(15000);
    win.SuperAppBridge.dispatchResponse({ id: request.id, success: true, data: { completed: action } });
    assert.deepEqual(await pending, { completed: action });
  }
});

test('interactive defaults match native, simulator and Flutter raw-JS bridge', async (t) => {
  const scheduled = [];
  const originalSetTimeout = globalThis.setTimeout;
  t.mock.method(globalThis, 'setTimeout', (fn, ms) => {
    scheduled.push(ms);
    return originalSetTimeout(fn, ms);
  });
  attachHost();
  const native = new NativeBridgeTransport();
  for (const action of INTERACTIVE_BRIDGE_ACTIONS) {
    await native.invoke(action);
    assert.equal(scheduled.pop(), 300000, action);
  }
  let receiver;
  win.addEventListener = (name, listener) => { if (name === 'message') receiver = listener; };
  win.parent = { postMessage({ request }) {
    receiver({ data: { type: 'SUPERAPP_BRIDGE_RESPONSE', response: { id: request.id, success: true } } });
  } };
  const simulator = new PostMessageTransport();
  for (const action of INTERACTIVE_BRIDGE_ACTIONS) {
    await simulator.invoke(action);
    assert.equal(scheduled.pop(), 300000, action);
  }
  vm.runInNewContext(flutterHostPolyfill, { window: win, console,
    setTimeout: globalThis.setTimeout, clearTimeout });
  for (const action of INTERACTIVE_BRIDGE_ACTIONS) {
    await win.bridge.invoke(action);
    assert.equal(scheduled.pop(), 300000, action);
  }
  assert.equal(bridgeTimeoutMs('getSystemInfo'), 60000);
  assert.equal(bridgeTimeoutMs('scanQr', 2000), 2000);
});

test('explicit per-call and client timeouts still override interactive defaults', async (t) => {
  const scheduled = [];
  const originalSetTimeout = globalThis.setTimeout;
  t.mock.method(globalThis, 'setTimeout', (fn, ms) => {
    scheduled.push(ms);
    return originalSetTimeout(fn, ms);
  });
  attachHost();
  const native = new NativeBridgeTransport({ timeoutMs: 9000 });
  await native.invoke('scanQr');
  assert.equal(scheduled.pop(), 9000);
  await native.invoke('getPhoto', {}, 120000);
  assert.equal(scheduled.pop(), 120000);
});

test('typed SDK methods preserve the native JSON response without flattening or dropping fields', async () => {
  const responses = {
    'device.getNetworkInfo': {networkType: 'wifi', isConnected: true, isWifi: true, isMobile: false, ssid: null, bssid: null, ipAddress: '10.0.0.2', signalStrength: null, timestamp: 123},
    'device.getBatteryInfo': {level: 42, isCharging: false, status: 'discharging', temperature: null, timestamp: 123},
    'getContacts': {contacts: [], total: 0},
    'ui.showConfirm': {confirmed: false},
    'ui.showToast': {success: true, message: 'Hello', durationMs: 2000},
    'storage.getItem': {key: 'test', value: '{"a":1}', exists: true, domain: 'default', securityLevel: 'KEYCHAIN_OR_KEYSTORE'},
  };
  win.FlutterBridge = {postMessage(raw) {
    const req = JSON.parse(raw);
    win.SuperAppBridge.dispatchResponse({id: req.id, success: true, data: responses[req.action]});
  }};
  const sdk = new SuperAppSDK();
  assert.deepEqual(await sdk.getNetworkInfo(), responses['device.getNetworkInfo']);
  assert.deepEqual(await sdk.getBatteryInfo(), responses['device.getBatteryInfo']);
  assert.deepEqual(await sdk.getContacts(), responses['getContacts']);
  assert.deepEqual(await sdk.ui.showConfirm({message: 'Continue?'}), responses['ui.showConfirm']);
  assert.deepEqual(await sdk.showToast('Hello'), responses['ui.showToast']);
  assert.deepEqual(await sdk.storage.getItem('test'), responses['storage.getItem']);
});

test('legacy mock-engine import cannot generate fake native responses', async () => {
  const {SDKMockEngine, MOCK_USER_PRESETS} = await import('../dist/mock/index.js');
  assert.deepEqual(MOCK_USER_PRESETS, {});
  const result = await new SDKMockEngine().dispatch({id: 'test', action: 'getContacts'});
  assert.equal(result.success, false);
  assert.equal(result.error.code, 'NATIVE_NOT_AVAILABLE');
  assert.equal(result.data, undefined);
});
