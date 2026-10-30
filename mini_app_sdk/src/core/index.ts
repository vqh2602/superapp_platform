import { SuperAppSDK } from './client.js';
import { AuthBackend } from './modules/auth.js';

// Default singleton instance ready to use
export const superApp = new SuperAppSDK();
export const authBackend = new AuthBackend(superApp.transport);
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
export * from './modules/payment.js';
export * from './modules/permissions.js';
export * from './modules/file.js';
export * from './modules/phone.js';
export * from './modules/utility.js';
export * from './modules/debug.js';
export * from './modules/system.js';
