import { BridgeTransport } from '../bridgeTransport';
import { MockOrder } from '../types';

export class PaymentModule {
  constructor(private transport: BridgeTransport) {}

  public async createOrder(data: {
    amount: number;
    description: string;
    currency?: string;
  }): Promise<MockOrder> {
    return this.transport.invoke<MockOrder>('payment.createOrder', data);
  }

  public async openCheckout(orderId: string): Promise<{
    orderId: string;
    status: 'SUCCESS' | 'FAILED' | 'CANCELLED';
    paymentMethod?: string;
    completedAt?: string;
    message?: string;
  }> {
    return this.transport.invoke('payment.openCheckout', { orderId });
  }
}
