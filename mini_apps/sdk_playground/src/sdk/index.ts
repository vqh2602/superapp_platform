/**
 * Mini App SDK Re-export from official library: @vqh2602/mini-app-sdk
 * The playground now consumes the official SDK package directly.
 */
import superApp, { authBackend, SuperAppSDK } from '@vqh2602/mini-app-sdk';

export * from '@vqh2602/mini-app-sdk';
export { superApp, authBackend, SuperAppSDK };
export default superApp;
