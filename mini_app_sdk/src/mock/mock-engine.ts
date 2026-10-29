import { BridgeRequest, BridgeResponse } from '../transport/index.js';
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
  public readonly device: DeviceMockHandler;
  public readonly storage: StorageMockHandler;
  public readonly ui: UIMockHandler;
  public readonly media: MediaMockHandler;
  public readonly payment: PaymentMockHandler;

  private latencyMs: number;
  private logListeners: Set<LogListener> = new Set();
  private logs: MockLogEntry[] = [];

  constructor(options: MockEngineOptions = {}) {
    this.store = new MockStateStore(options.storageKeyPrefix);
    this.latencyMs = options.simulatedLatencyMs ?? 40;

    this.auth = new AuthMockHandler(this.store);
    this.device = new DeviceMockHandler(this.store);
    this.storage = new StorageMockHandler(this.store);
    this.ui = new UIMockHandler();
    this.media = new MediaMockHandler();
    this.payment = new PaymentMockHandler(this.store);
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
      // 1. Auth & User
      case 'auth.login':
      case 'login':
        return this.auth.login(p);
      case 'auth.requestCode':
        return this.auth.requestCode(p);
      case 'auth.exchangeCode':
        return this.auth.exchangeCode(p);
      case 'auth.getAccessToken':
      case 'getAccessToken':
        return this.auth.getAccessToken();
      case 'auth.getUserProfile':
      case 'getUserProfile':
      case 'user.getProfile':
        return this.auth.getUserProfile();
      case 'user.getBasicInfo':
        return this.auth.getBasicInfo();
      case 'auth.refreshToken':
        return this.auth.refreshToken(p);
      case 'auth.logout':
        return this.auth.logout();

      // 2. Payment
      case 'payment.requestPayment':
      case 'payment.openCheckout':
      case 'requestPayment':
        return this.payment.requestPayment(p);
      case 'payment.createOrder':
        return this.payment.createOrder(p);

      // 3. Device & System
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
      case 'getAppInfo':
        return {
          appId: appId || 'mini_app',
          version: '1.0.0',
          platformVersion: '2.0.0',
          appName: 'SuperApp Mini App',
        };
      case 'device.getLocation':
      case 'getLocation':
        return {
          latitude: 21.028511,
          longitude: 105.854167,
          accuracy: 10,
          altitude: 12,
          speed: 0,
          address: 'Hà Nội, Việt Nam',
        };
      case 'getDeviceLanguage':
        return { language: this.store.getDeviceState().language || 'vi-VN' };
      case 'getSuperAppSettings':
        return {
          theme: 'dark',
          notificationsEnabled: true,
          language: 'vi-VN',
          appVersion: '1.0.0',
        };
      case 'device.vibrate':
      case 'vibrate':
        return this.device.vibrate(p);
      case 'device.keepScreen':
      case 'keepScreen':
        return this.device.keepScreen(p);
      case 'copyToClipboard':
        return { success: true, text: p.text };
      case 'setBrightness':
        return { success: true, brightness: p.brightness };
      case 'getContacts':
        return {
          contacts: [
            { id: 'c_01', name: 'Nguyễn Văn An', phone: '0988123456', email: 'an.nguyen@example.com' },
            { id: 'c_02', name: 'Trần Thị Mai', phone: '0912345678', email: 'mai.tran@example.com' },
          ],
        };

      // 4. Permissions
      case 'permission.request':
      case 'permission.check':
      case 'permission.getPermissions':
        return {
          granted: true,
          capability: p.capability,
          permissions: {
            camera: 'granted',
            location: 'granted',
            notification: 'granted',
            photos: 'granted',
          },
        };

      // 5. Storage & Credentials
      case 'storage.getItem':
      case 'getStorage':
      case 'storage.getSecureItem':
      case 'storage.getSecretData':
      case 'getSecretData':
        return this.storage.getItem(appId, p);
      case 'storage.setItem':
      case 'setStorage':
      case 'storage.setSecureItem':
      case 'storage.setSecretData':
      case 'setSecretData':
        return this.storage.setItem(appId, p);
      case 'storage.removeItem':
      case 'removeStorage':
      case 'storage.removeSecureItem':
      case 'storage.removeSecretData':
      case 'removeSecretData':
        return this.storage.removeItem(appId, p);
      case 'storage.clear':
      case 'clearStorage':
        return this.storage.clear(appId);
      case 'storage.getAll':
        return this.storage.getAll(appId);
      case 'storage.getCredentials':
        return {
          username: this.store.getUser().email,
          token: this.store.getSession()?.accessToken,
          role: this.store.getUser().role,
        };
      case 'storage.setCredentials':
      case 'storage.deleteCredentials':
        return { success: true };

      // 6. UI
      case 'ui.showToast':
      case 'showToast':
        return this.ui.showToast(p);
      case 'ui.showAlert':
      case 'showAlert':
        return this.ui.showAlert(p);
      case 'ui.showConfirm':
      case 'showConfirm':
        return this.ui.showConfirm(p);
      case 'ui.setNavigationBarTitle':
      case 'setTitle':
      case 'setNavigationBarTitle':
        return this.ui.setNavigationBarTitle(p);
      case 'ui.setStatusBarColor':
      case 'setStatusBarColor':
        return this.ui.setStatusBarColor(p);
      case 'ui.setNavigationBarColor':
      case 'setNavigationBarColor':
        return this.ui.setNavigationBarColor(p);
      case 'ui.configAppView':
      case 'configAppView':
        return this.ui.configAppView(p);
      case 'ui.requestSendNotification':
      case 'requestSendNotification':
        return this.ui.requestSendNotification(p);
      case 'showMiniappMenu':
      case 'ui.showMiniappMenu':
        return { success: true, message: 'Menu triggered' };

      // 7. Media & Files
      case 'media.scanQRCode':
      case 'scanQr':
      case 'device.scanQRCode':
        return this.media.scanQRCode(p);
      case 'media.chooseImage':
      case 'getPhoto':
      case 'device.pickImage':
      case 'pickImages':
        return this.media.chooseImage(p);
      case 'saveImageToGallery':
      case 'saveVideoToGallery':
      case 'pickVideo':
      case 'saveFile':
      case 'pickFile':
      case 'filePreview':
        return {
          success: true,
          uri: p.uri || 'mock_file_uri_' + Date.now(),
          name: p.fileName || 'demo_file.png',
        };

      // 8. Navigation / Lifecycle
      case 'navigation.closeApp':
      case 'closeApp':
      case 'navigation.close':
        return { success: true, message: 'App closed' };
      case 'navigation.minimizeApp':
      case 'minimizeApp':
        return { success: true, status: 'minimized', appId };
      case 'navigation.openMiniApp':
        return { success: true, targetAppId: p.appId };
      case 'navigation.openNativePage':
        return { success: true, page: p.page, params: p.params };

      // 9. Phone & Utilities
      case 'openPhone':
      case 'openSMS':
      case 'openExternalBrowser':
      case 'openDeepLink':
        return { success: true };
      case 'speechToText':
        return { success: true, text: 'Nội dung nhận diện giọng nói thử nghiệm', lang: p.lang || 'vi-VN' };
      case 'hideKeyboard':
        return { success: true };

      // 10. Debug
      case 'debug.echo':
        return p;
      case 'debug.simulateFailure':
        throw {
          code: p.type || 'SIMULATED_FAILURE',
          message: 'Mô phỏng lỗi debug từ Simulator',
        };

      default:
        // Graceful fallback instead of crashing
        console.warn(`[SDKMockEngine] Action "${action}" not specifically handled. Returning generic success.`);
        return { success: true, action, payload: p };
    }
  }
}
