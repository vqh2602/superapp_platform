import { SuperAppSDK } from './client.js';

// Default singleton instance ready to use
export const superApp = new SuperAppSDK();
export default superApp;

export { SuperAppSDK } from './client.js';
export * from './types/index.js';
export * from './modules/auth.js';
export * from './modules/payment.js';
export * from './modules/device.js';
export * from './modules/storage.js';
export * from './modules/ui.js';
export * from './modules/navigation.js';
export * from './modules/media.js';
export * from './modules/lifecycle.js';
