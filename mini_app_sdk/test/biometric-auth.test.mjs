import { test } from 'node:test';
import assert from 'node:assert/strict';
import { AuthModule } from '../dist/core/modules/auth.js';
import { bridgeTimeoutMs, INTERACTIVE_BRIDGE_TIMEOUT_MS } from '../dist/transport/timeout-policy.js';

test('biometric SDK methods forward typed results and options', async () => {
  const calls = [];
  const status = { supported: true, enrolled: true, canAuthenticate: true, availableBiometrics: ['face'] };
  const auth = new AuthModule({ invoke: async (action, payload) => {
    calls.push({ action, payload });
    return action === 'auth.checkBiometrics' ? status : { authenticated: false };
  } });
  assert.deepEqual(await auth.checkBiometrics(), status);
  assert.deepEqual(await auth.authenticateBiometric({ reason: 'Verify' }), { authenticated: false });
  assert.deepEqual(calls, [
    { action: 'auth.checkBiometrics', payload: undefined },
    { action: 'auth.authenticateBiometric', payload: { reason: 'Verify' } },
  ]);
  assert.equal(bridgeTimeoutMs('auth.authenticateBiometric'), INTERACTIVE_BRIDGE_TIMEOUT_MS);
});

test('native cancellation propagates without reporting success', async () => {
  const error = { code: 'CANCELLED', message: 'Cancelled' };
  const auth = new AuthModule({ invoke: async () => { throw error; } });
  await assert.rejects(auth.authenticateBiometric(), (actual) => actual === error);
});
