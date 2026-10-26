import { BridgeRequest, BridgeResponse, BridgeError, BridgeEventListener } from './types';

declare global {
  interface Window {
    FlutterBridge?: {
      postMessage: (msg: string) => void;
    };
    SuperAppBridge?: {
      _callbacks: Record<string, (res: BridgeResponse) => void>;
      _listeners: Record<string, BridgeEventListener[]>;
      postMessage: (msg: any) => void;
      dispatchResponse: (res: BridgeResponse) => void;
      dispatchEvent: (evt: { event: string; payload: any }) => void;
      addEventListener: (event: string, handler: BridgeEventListener) => void;
      removeEventListener: (event: string, handler: BridgeEventListener) => void;
    };
  }
}

let requestSeq = 1;

export class BridgeTransport {
  private appId: string;
  private isNativeBridgeAvailable: boolean;

  constructor(appId: string = 'sdk_playground') {
    this.appId = appId;
    this.isNativeBridgeAvailable = typeof window !== 'undefined' && !!(window.FlutterBridge?.postMessage || window.SuperAppBridge?.postMessage);
  }

  public isConnectedToNative(): boolean {
    return typeof window !== 'undefined' && !!window.FlutterBridge?.postMessage;
  }

  public invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs: number = 8000): Promise<T> {
    const id = `req_${Date.now()}_${requestSeq++}`;
    const timestamp = Date.now();

    const request: BridgeRequest = {
      id,
      action,
      payload,
      appId: this.appId,
      origin: typeof window !== 'undefined' ? window.location.origin : 'miniapp://sdk_playground',
      timestamp,
    };

    return new Promise<T>((resolve, reject) => {
      // Setup timeout
      const timer = setTimeout(() => {
        if (window.SuperAppBridge?._callbacks?.[id]) {
          delete window.SuperAppBridge._callbacks[id];
        }
        reject({
          code: 'TIMEOUT',
          message: `Bridge call "${action}" timed out after ${timeoutMs}ms`,
        } as BridgeError);
      }, timeoutMs);

      // If running inside Flutter WebView with native bridge
      if (this.isConnectedToNative()) {
        if (!window.SuperAppBridge) {
          window.SuperAppBridge = {
            _callbacks: {},
            _listeners: {},
            postMessage: (msg) => window.FlutterBridge?.postMessage(JSON.stringify(msg)),
            dispatchResponse: (res) => window.SuperAppBridge?._callbacks[res.id]?.(res),
            dispatchEvent: (evt) => {
              const list = window.SuperAppBridge?._listeners[evt.event] || [];
              list.forEach((fn) => fn(evt.payload));
            },
            addEventListener: (event, handler) => {
              window.SuperAppBridge!._listeners[event] = window.SuperAppBridge!._listeners[event] || [];
              window.SuperAppBridge!._listeners[event].push(handler);
            },
            removeEventListener: (event, handler) => {
              if (!window.SuperAppBridge?._listeners[event]) return;
              window.SuperAppBridge._listeners[event] = window.SuperAppBridge._listeners[event].filter((h) => h !== handler);
            },
          };
        }

        window.SuperAppBridge._callbacks[id] = (response: BridgeResponse<T>) => {
          clearTimeout(timer);
          if (response.success) {
            resolve(response.data as T);
          } else {
            reject(response.error || { code: 'INTERNAL_ERROR', message: 'Unknown error occurred' });
          }
        };

        window.FlutterBridge!.postMessage(JSON.stringify(request));
      } else {
        // Fallback Browser Simulator Transport
        this.simulateBrowserTransport<T>(action, payload)
          .then((data) => {
            clearTimeout(timer);
            resolve(data);
          })
          .catch((err) => {
            clearTimeout(timer);
            reject(err);
          });
      }
    });
  }

  public addEventListener(event: string, handler: BridgeEventListener): () => void {
    if (typeof window === 'undefined') return () => {};
    if (!window.SuperAppBridge) {
      window.SuperAppBridge = {
        _callbacks: {},
        _listeners: {},
        postMessage: () => {},
        dispatchResponse: () => {},
        dispatchEvent: () => {},
        addEventListener: () => {},
        removeEventListener: () => {},
      };
    }

    if (!window.SuperAppBridge._listeners[event]) {
      window.SuperAppBridge._listeners[event] = [];
    }
    window.SuperAppBridge._listeners[event].push(handler);

    return () => {
      if (window.SuperAppBridge?._listeners[event]) {
        window.SuperAppBridge._listeners[event] = window.SuperAppBridge._listeners[event].filter((h) => h !== handler);
      }
    };
  }

  private async simulateBrowserTransport<T>(action: string, payload: Record<string, any>): Promise<T> {
    await new Promise((r) => setTimeout(r, 300));

    switch (action) {
      case 'auth.requestCode':
        return {
          authCode: `AUTH_SDK_PLAYGROUND_${Math.floor(100000 + Math.random() * 900000)}`,
          expiresIn: 60,
          userId: 'user_001',
          createdAt: new Date().toISOString(),
        } as any;

      case 'auth.exchangeCode':
        return {
          accessToken: `sim_mini_at_${Math.random().toString(36).substring(2)}`,
          refreshToken: `sim_mini_rt_${Math.random().toString(36).substring(2)}`,
          tokenType: 'Bearer',
          expiresIn: 300,
          userId: 'user_001',
          appId: this.appId,
        } as any;

      case 'auth.refreshToken':
        return {
          accessToken: `sim_mini_at_refreshed_${Math.random().toString(36).substring(2)}`,
          refreshToken: `sim_mini_rt_new_${Math.random().toString(36).substring(2)}`,
          tokenType: 'Bearer',
          expiresIn: 300,
          userId: 'user_001',
          appId: this.appId,
        } as any;

      case 'user.getProfile':
        return {
          id: 'user_001',
          name: 'Nguyễn Văn A (Simulated Browser)',
          phone: '0900000001',
          role: 'customer',
          email: 'nguyenvana@example.com',
        } as any;

      case 'user.getBasicInfo':
        return {
          id: 'user_001',
          name: 'Nguyễn Văn A',
        } as any;

      case 'device.scanQRCode':
        return {
          content: 'https://superapp.mock/pay?qr_token=SIM_QR_998877',
          format: 'QR_CODE',
          timestamp: Date.now(),
          isMock: true,
        } as any;

      case 'device.getLocation':
        return {
          latitude: 10.776889,
          longitude: 106.700806,
          city: 'Hồ Chí Minh (Simulated)',
          country: 'Việt Nam',
          timestamp: Date.now(),
          isMock: true,
        } as any;

      case 'device.pickImage':
        return {
          uri: 'content://mock/photos/photo_demo_01.jpg',
          mimeType: 'image/jpeg',
          width: 1080,
          height: 1920,
          sizeBytes: 245120,
          fileName: 'photo_demo_01.jpg',
          isMock: true,
        } as any;

      case 'payment.createOrder':
        return {
          orderId: `ORD_${Date.now()}_SIM`,
          amount: payload.amount || 50000,
          currency: 'VND',
          description: payload.description || 'Thanh toán đơn hàng (Browser Sim)',
          status: 'PENDING',
          appId: this.appId,
          userId: 'user_001',
          createdAt: new Date().toISOString(),
        } as any;

      case 'payment.openCheckout':
        return {
          orderId: payload.orderId || 'ORD_SIM',
          status: 'SUCCESS',
          paymentMethod: 'SUPERAPP_WALLET',
          completedAt: new Date().toISOString(),
        } as any;

      case 'permission.request':
      case 'permission.check':
        return {
          capability: payload.capability,
          granted: true,
        } as any;

      case 'debug.echo':
        return {
          echo: payload,
          appId: this.appId,
          timestamp: Date.now(),
        } as any;

      case 'debug.simulateFailure':
        throw {
          code: payload.type === 'timeout' ? 'TIMEOUT' : 'INTERNAL_ERROR',
          message: `Browser simulated failure: ${payload.type}`,
        };

      default:
        throw {
          code: 'ACTION_NOT_FOUND',
          message: `Action not found in browser simulator: ${action}`,
        };
    }
  }
}
