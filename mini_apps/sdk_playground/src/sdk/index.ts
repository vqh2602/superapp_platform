import { BridgeTransport } from './bridgeTransport';
import { AuthModule, MockAuthBackend } from './modules/auth';
import { UserModule } from './modules/user';
import { NavigationModule } from './modules/navigation';
import { DeviceModule } from './modules/device';
import { PaymentModule } from './modules/payment';
import { PermissionsModule } from './modules/permissions';
import { LifecycleModule } from './modules/lifecycle';
import { DebugModule } from './modules/debug';

export * from './types';
export { BridgeTransport } from './bridgeTransport';

export class SuperAppSDK {
  public readonly version = '1.0.0';
  public readonly transport: BridgeTransport;

  public readonly auth: AuthModule;
  public readonly user: UserModule;
  public readonly navigation: NavigationModule;
  public readonly device: DeviceModule;
  public readonly payment: PaymentModule;
  public readonly permission: PermissionsModule;
  public readonly lifecycle: LifecycleModule;
  public readonly debug: DebugModule;

  constructor(appId: string = 'sdk_playground') {
    this.transport = new BridgeTransport(appId);
    this.auth = new AuthModule(this.transport);
    this.user = new UserModule(this.transport);
    this.navigation = new NavigationModule(this.transport);
    this.device = new DeviceModule(this.transport);
    this.payment = new PaymentModule(this.transport);
    this.permission = new PermissionsModule(this.transport);
    this.lifecycle = new LifecycleModule(this.transport);
    this.debug = new DebugModule(this.transport);
  }

  public isConnected(): boolean {
    return this.transport.isConnectedToNative();
  }
}

// Global default instances
export const superApp = new SuperAppSDK('sdk_playground');
export const mockAuthBackend = new MockAuthBackend(superApp.transport);
