import { BridgeRequest, BridgeResponse } from '@superapp/sdk-transport';
import { AuthMockHandler } from './handlers/auth.handler.js';
import { DeviceMockHandler } from './handlers/device.handler.js';
import { MediaMockHandler } from './handlers/media.handler.js';
import { PaymentMockHandler } from './handlers/payment.handler.js';
import { StorageMockHandler } from './handlers/storage.handler.js';
import { UIMockHandler } from './handlers/ui.handler.js';
import { MockStateStore } from './store.js';
import { MockEngineOptions } from './types.js';

export interface MockLogEntry {
  id: string;
  action: string;
  payload: any;
  response?: any;
  error?: any;
  durationMs: number;
  timestamp: number;
  success: boolean;
}

export type LogListener = (entry: MockLogEntry) => void;

export class SDKMockEngine {
  public readonly store: MockStateStore;
  public readonly auth: AuthMockHandler;
  public readonly payment: PaymentMockHandler;
  public readonly device: DeviceMockHandler;
  public readonly storage: StorageMockHandler;
  public readonly ui: UIMockHandler;
  public readonly media: MediaMockHandler;

  private latencyMs: number;
  private logListeners: Set<LogListener> = new Set();
  private logs: MockLogEntry[] = [];

  constructor(options: MockEngineOptions = {}) {
    this.store = new MockStateStore(options.storageKeyPrefix);
    this.latencyMs = options.simulatedLatencyMs ?? 40;

    this.auth = new AuthMockHandler(this.store);
    this.payment = new PaymentMockHandler(this.store, options.autoApprovePayment ?? true);
    this.device = new DeviceMockHandler(this.store);
    this.storage = new StorageMockHandler(this.store);
    this.ui = new UIMockHandler();
    this.media = new MediaMockHandler();
  }

  public setLatency(ms: number): void {
    this.latencyMs = ms;
  }

  public onLog(listener: LogListener): () => void {
    this.logListeners.add(listener);
    return () => this.logListeners.delete(listener);
  }

  public getLogs(): MockLogEntry[] {
    return [...this.logs];
  }

  public clearLogs(): void {
    this.logs = [];
  }

  public async dispatch(request: BridgeRequest): Promise<BridgeResponse> {
    const startTime = Date.now();

    // Simulate network/thread latency
    if (this.latencyMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, this.latencyMs));
    }

    try {
      const data = await this.routeAction(request);
      const durationMs = Date.now() - startTime;

      const response: BridgeResponse = {
        id: request.id,
        action: request.action,
        success: true,
        data,
        timestamp: Date.now(),
      };

      this.recordLog({
        id: request.id,
        action: request.action,
        payload: request.payload,
        response: data,
        durationMs,
        timestamp: startTime,
        success: true,
      });

      return response;
    } catch (err: any) {
      const durationMs = Date.now() - startTime;
      const errorObj = {
        code: err?.code || 'ACTION_FAILED',
        message: err?.message || 'Operation failed in mock engine',
        details: err?.details,
      };

      const response: BridgeResponse = {
        id: request.id,
        action: request.action,
        success: false,
        error: errorObj,
        timestamp: Date.now(),
      };

      this.recordLog({
        id: request.id,
        action: request.action,
        payload: request.payload,
        error: errorObj,
        durationMs,
        timestamp: startTime,
        success: false,
      });

      return response;
    }
  }

  private recordLog(entry: MockLogEntry): void {
    this.logs.unshift(entry);
    if (this.logs.length > 200) {
      this.logs.pop();
    }
    this.logListeners.forEach((listener) => {
      try {
        listener(entry);
      } catch (e) {
        console.error('[SDKMockEngine] Error in log listener:', e);
      }
    });
  }

  private async routeAction(request: BridgeRequest): Promise<any> {
    const { action, payload, appId } = request;
    const p: any = payload || {};

    switch (action) {
      // Auth & User
      case 'auth.login':
      case 'login':
        return this.auth.login(p);
      case 'auth.getAccessToken':
      case 'getAccessToken':
        return this.auth.getAccessToken();
      case 'auth.getUserProfile':
      case 'getUserProfile':
        return this.auth.getUserProfile();
      case 'auth.refreshToken':
        return this.auth.refreshToken(p);
      case 'auth.logout':
        return this.auth.logout();

      // Payment
      case 'payment.requestPayment':
      case 'requestPayment':
        return this.payment.requestPayment(p);
      case 'payment.checkTransaction':
        return this.payment.checkTransaction(p);

      // Device & System
      case 'device.getBatteryInfo':
      case 'getBatteryInfo':
        return this.device.getBatteryInfo();
      case 'device.getNetworkInfo':
      case 'getNetworkInfo':
        return this.device.getNetworkInfo();
      case 'device.getDeviceInfo':
      case 'getDeviceInfo':
        return this.device.getDeviceInfo();
      case 'device.getSystemInfo':
      case 'getSystemInfo':
        return this.device.getSystemInfo();
      case 'device.vibrate':
      case 'vibrate':
        return this.device.vibrate(p);

      // Storage
      case 'storage.getItem':
      case 'getStorage':
        return this.storage.getItem(appId, p);
      case 'storage.setItem':
      case 'setStorage':
        return this.storage.setItem(appId, p);
      case 'storage.removeItem':
      case 'removeStorage':
        return this.storage.removeItem(appId, p);
      case 'storage.clear':
      case 'clearStorage':
        return this.storage.clear(appId);
      case 'storage.getAll':
        return this.storage.getAll(appId);

      // UI
      case 'ui.showToast':
      case 'showToast':
        return this.ui.showToast(p);
      case 'ui.showAlert':
      case 'showAlert':
        return this.ui.showAlert(p);
      case 'ui.showConfirm':
        return this.ui.showConfirm(p);
      case 'ui.setNavigationBarTitle':
      case 'setTitle':
        return this.ui.setNavigationBarTitle(p);
      case 'ui.setStatusBarColor':
        return this.ui.setStatusBarColor(p);

      // Media
      case 'media.scanQRCode':
      case 'scanQr':
        return this.media.scanQRCode(p);
      case 'media.chooseImage':
      case 'getPhoto':
        return this.media.chooseImage(p);

      // Navigation / Lifecycle
      case 'navigation.closeApp':
      case 'closeApp':
        return { success: true, message: 'App closed' };

      default:
        throw {
          code: 'UNSUPPORTED_ACTION',
          message: `Mock action "${action}" is not implemented in SDKMockEngine.`,
        };
    }
  }
}
