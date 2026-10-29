import { ITransport } from './transport.interface.js';
import { NativeBridgeTransport } from './native-transport.js';
import { PostMessageTransport } from './postmessage-transport.js';
import { MockBridgeTransport, MockDispatcher } from './mock-transport.js';
import { AdaptiveBridgeTransport } from './adaptive-transport.js';
import { TransportConfig, TransportType } from './types.js';

export interface TransportResolverOptions extends TransportConfig {
  forceTransport?: TransportType;
  mockDispatcher?: MockDispatcher;
}

export class TransportResolver {
  public static resolve(options: TransportResolverOptions = {}): ITransport {
    // 1. Explicit override if requested
    if (options.forceTransport === 'native') {
      return new NativeBridgeTransport(options);
    }
    if (options.forceTransport === 'postmessage') {
      return new PostMessageTransport(options);
    }
    if (options.forceTransport === 'mock') {
      return new MockBridgeTransport({ ...options, dispatcher: options.mockDispatcher });
    }

    // 2. Default: Dynamic Adaptive Bridge Transport that automatically detects and routes calls
    return new AdaptiveBridgeTransport(options);
  }
}
