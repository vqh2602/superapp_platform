import { ITransport, MockBridgeTransport, TransportResolver, TransportType } from '@superapp/sdk-transport';
import { SDKMockEngine } from '@superapp/sdk-mock-engine';
import { AuthModule } from './modules/auth.js';
import { DeviceModule } from './modules/device.js';
import { StorageModule } from './modules/storage.js';
import { UIModule } from './modules/ui.js';
import { NavigationModule } from './modules/navigation.js';
import { MediaModule } from './modules/media.js';
import { LifecycleModule } from './modules/lifecycle.js';
import {
  AuthLoginOptions,
  AuthLoginResult,
  ConfigAppViewOptions,
  KeepScreenOptions,
  MinimizeAppResult,
  NotificationResult,
  RequestSendNotificationOptions,
  SDKInitOptions,
  SetNavigationBarColorOptions,
  ToastOptions,
  UserProfile,
} from './types/index.js';

export class SuperAppSDK {
  public readonly version = '1.0.0';
  public readonly transport: ITransport;
  public readonly mockEngine?: SDKMockEngine;

  // Domain modules
  public readonly auth: AuthModule;
  public readonly device: DeviceModule;
  public readonly storage: StorageModule;
  public readonly ui: UIModule;
  public readonly navigation: NavigationModule;
  public readonly media: MediaModule;
  public readonly lifecycle: LifecycleModule;

  constructor(options: SDKInitOptions & { forceTransport?: TransportType } = {}) {
    // If running in pure mock environment, setup local engine
    let mockEngine: SDKMockEngine | undefined;
    let mockDispatcher;

    // Detect if need fallback mock dispatcher
    const needsMock = options.forceTransport === 'mock' ||
      (typeof window === 'undefined' || (!(window as any).FlutterBridge && window.parent === window));

    if (needsMock) {
      mockEngine = new SDKMockEngine({ autoApprovePayment: true });
      mockDispatcher = (req: any) => mockEngine!.dispatch(req);
    }

    this.mockEngine = mockEngine;
    this.transport = TransportResolver.resolve({
      appId: options.appId,
      debug: options.debug,
      timeoutMs: options.timeoutMs,
      forceTransport: options.forceTransport,
      mockDispatcher,
    });

    // If MockBridgeTransport was created and we have mockEngine, attach
    if (this.transport instanceof MockBridgeTransport && mockDispatcher) {
      this.transport.setDispatcher(mockDispatcher);
    }

    this.auth = new AuthModule(this.transport);
    this.device = new DeviceModule(this.transport);
    this.storage = new StorageModule(this.transport);
    this.ui = new UIModule(this.transport);
    this.navigation = new NavigationModule(this.transport);
    this.media = new MediaModule(this.transport);
    this.lifecycle = new LifecycleModule(this.transport);
  }

  // Top-level shortcuts
  public login(options?: AuthLoginOptions): Promise<AuthLoginResult> {
    return this.auth.login(options);
  }

  public getUserProfile(): Promise<UserProfile> {
    return this.auth.getUserProfile();
  }

  public showToast(options: ToastOptions | string): Promise<void> {
    return this.ui.showToast(options);
  }

  public vibrate(style?: 'light' | 'medium' | 'heavy'): Promise<void> {
    return this.device.vibrate(style);
  }

  public closeApp(): Promise<void> {
    return this.navigation.closeApp();
  }

  public minimizeApp(): Promise<MinimizeAppResult> {
    return this.navigation.minimizeApp();
  }

  public configAppView(options: ConfigAppViewOptions): Promise<any> {
    return this.ui.configAppView(options);
  }

  public setNavigationBarTitle(title: string | { title: string }): Promise<void> {
    return this.ui.setNavigationBarTitle(title);
  }

  public setNavigationBarColor(options: SetNavigationBarColorOptions | string): Promise<void> {
    return this.ui.setNavigationBarColor(options);
  }

  public keepScreen(options?: KeepScreenOptions | boolean): Promise<{ success: boolean; keepScreenOn: boolean }> {
    return this.device.keepScreen(options);
  }

  public requestSendNotification(options?: RequestSendNotificationOptions): Promise<NotificationResult> {
    return this.ui.requestSendNotification(options);
  }

  public on(event: string, callback: (payload: any) => void): () => void {
    return this.transport.on(event, callback);
  }

  public off(event: string, callback: (payload: any) => void): void {
    this.transport.off(event, callback);
  }
}
