import { superApp, SuperAppSDK } from './core/index.js';

export default superApp;
export { superApp, SuperAppSDK };

// Re-export all core modules and types
export * from './core/index.js';

// Re-export transport interfaces & classes
export {
  ITransport,
  NativeBridgeTransport,
  PostMessageTransport,
  MockBridgeTransport,
  TransportResolver,
  TransportType,
  BridgeRequest,
  BridgeResponse,
  BridgeEventListener,
  BridgeError,
} from './transport/index.js';

// Re-export mock engine classes & presets
export {
  SDKMockEngine,
  MockStateStore,
  MOCK_USER_PRESETS,
  MockUserProfile,
  MockPaymentOrder,
  MockDeviceState,
  MockNetworkCondition,
  MockLogEntry,
} from './mock/index.js';

// Sub-namespaces
export * as transport from './transport/index.js';
export * as mock from './mock/index.js';
