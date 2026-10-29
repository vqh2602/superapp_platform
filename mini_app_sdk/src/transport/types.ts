export type TransportType = 'native' | 'postmessage' | 'mock' | 'adaptive';

export interface BridgeRequest<T = Record<string, any>> {
  id: string;
  action: string;
  payload: T;
  appId: string;
  origin?: string;
  timestamp: number;
}

export interface BridgeError {
  code: string;
  message: string;
  details?: any;
}

export interface BridgeResponse<T = any> {
  id: string;
  action: string;
  success: boolean;
  data?: T;
  error?: BridgeError;
  timestamp?: number;
}

export type BridgeEventListener<T = any> = (payload: T) => void;

export interface TransportConfig {
  appId?: string;
  timeoutMs?: number;
  debug?: boolean;
}

export interface NativeWindowBridge {
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
