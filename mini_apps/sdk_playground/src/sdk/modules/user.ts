import { BridgeTransport } from '../bridgeTransport';
import { UserProfile, BasicUserInfo } from '../types';

export class UserModule {
  constructor(private transport: BridgeTransport) {}

  public async getProfile(): Promise<UserProfile> {
    return this.transport.invoke<UserProfile>('user.getProfile');
  }

  public async getBasicInfo(): Promise<BasicUserInfo> {
    return this.transport.invoke<BasicUserInfo>('user.getBasicInfo');
  }
}
