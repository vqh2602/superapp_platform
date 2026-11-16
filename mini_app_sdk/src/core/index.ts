import { SuperAppSDK } from './client.js';
import { AuthBackend } from './modules/auth.js';

let _superAppInstance: SuperAppSDK | undefined;
let _authBackendInstance: AuthBackend | undefined;

/**
 * Returns the default singleton SuperAppSDK instance, lazily instantiated
 * on first access to prevent eager side-effects during import.
 */
export function getSuperApp(): SuperAppSDK {
  if (!_superAppInstance) {
    _superAppInstance = new SuperAppSDK();
  }
  return _superAppInstance;
}

/**
 * Returns the default singleton AuthBackend instance, lazily instantiated
 * on first access.
 */
export function getAuthBackend(): AuthBackend {
  if (!_authBackendInstance) {
    _authBackendInstance = new AuthBackend(getSuperApp().transport);
  }
  return _authBackendInstance;
}

/**
 * Default singleton instance ready to use.
 * Implemented as a transparent Proxy so that `import superApp from '@vqh2602/mini-app-sdk'`
 * has zero side effects and does not instantiate transports or attach listeners until
 * the first property or method is accessed.
 */
export const superApp: SuperAppSDK = new Proxy({} as SuperAppSDK, {
  get(_target, prop) {
    if (prop === 'destroy' || prop === 'dispose') {
      return () => {
        if (_superAppInstance) {
          _superAppInstance.destroy();
          _superAppInstance = undefined;
        }
        if (_authBackendInstance) {
          _authBackendInstance = undefined;
        }
      };
    }
    const instance = getSuperApp();
    const val = Reflect.get(instance, prop);
    if (typeof val === 'function') {
      return val.bind(instance);
    }
    return val;
  },
  set(_target, prop, value) {
    const instance = getSuperApp();
    return Reflect.set(instance, prop, value);
  },
  has(_target, prop) {
    const instance = getSuperApp();
    return Reflect.has(instance, prop);
  },
  getPrototypeOf() {
    return SuperAppSDK.prototype;
  },
});

export const authBackend: AuthBackend = new Proxy({} as AuthBackend, {
  get(_target, prop) {
    const instance = getAuthBackend();
    const val = Reflect.get(instance, prop);
    if (typeof val === 'function') {
      return val.bind(instance);
    }
    return val;
  },
  getPrototypeOf() {
    return AuthBackend.prototype;
  },
});

export default superApp;

export { SuperAppSDK } from './client.js';
export * from './types/index.js';
export * from './modules/auth.js';
export * from './modules/device.js';
export * from './modules/storage.js';
export * from './modules/ui.js';
export * from './modules/navigation.js';
export * from './modules/media.js';
export * from './modules/lifecycle.js';
export * from './modules/user.js';
export * from './modules/permissions.js';
export * from './modules/file.js';
export * from './modules/phone.js';
export * from './modules/utility.js';
export * from './modules/debug.js';
export * from './modules/system.js';
