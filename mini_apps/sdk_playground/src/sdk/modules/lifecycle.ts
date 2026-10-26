import { BridgeTransport } from '../bridgeTransport';
import { BridgeEventListener } from '../types';

export class LifecycleModule {
  constructor(private transport: BridgeTransport) {}

  public on(event: string, listener: BridgeEventListener): () => void {
    return this.transport.addEventListener(event, listener);
  }

  public onShow(listener: () => void): () => void {
    return this.on('miniapp.show', listener);
  }

  public onHide(listener: () => void): () => void {
    return this.on('miniapp.hide', listener);
  }

  public onResume(listener: () => void): () => void {
    return this.on('miniapp.resume', listener);
  }

  public onClose(listener: () => void): () => void {
    return this.on('miniapp.close', listener);
  }

  public onSessionChanged(listener: (data: { state: string; userId?: string }) => void): () => void {
    return this.on('auth.sessionChanged', listener);
  }

  public onPaymentStatusChanged(listener: (data: { orderId: string; status: string }) => void): () => void {
    return this.on('payment.statusChanged', listener);
  }
}
