import { ITransport } from './transport.interface.js';
import { NativeBridgeTransport } from './native-transport.js';
import { PostMessageTransport } from './postmessage-transport.js';
import { MockBridgeTransport, MockDispatcher } from './mock-transport.js';
import { NativeWindowBridge, TransportConfig, TransportType } from './types.js';

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

    // 2. Automatic runtime environment detection
    if (typeof window !== 'undefined') {
      const win = window as unknown as NativeWindowBridge;

      // Real SuperApp Flutter WebView environment
      if (win.FlutterBridge?.postMessage) {
        if (options.debug) {
          console.info('[TransportResolver] Detected Native Flutter Bridge container.');
        }
        return new NativeBridgeTransport(options);
      }

      // Inside Simulator Iframe (parent is different window)
      if (window.parent && window.parent !== window) {
        if (options.debug) {
          console.info('[TransportResolver] Detected Browser Simulator parent iframe container.');
        }
        return new PostMessageTransport(options);
      }
    }

    // 3. Fallback: Mock Bridge Transport (for standalone browser tabs, local dev, or testing)
    if (options.debug) {
      console.info('[TransportResolver] Falling back to Mock Bridge Transport.');
    }
    return new MockBridgeTransport({ ...options, dispatcher: options.mockDispatcher });
  }
}
