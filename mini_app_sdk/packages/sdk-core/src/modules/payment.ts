import { ITransport } from '@superapp/sdk-transport';
import { PaymentOptions, PaymentResult } from '../types/index.js';

export class PaymentModule {
  constructor(private transport: ITransport) {}

  /**
   * Gọi cổng thanh toán SuperApp Checkout
   */
  public async requestPayment(options: PaymentOptions): Promise<PaymentResult> {
    if (!options.amount || options.amount <= 0) {
      throw new Error('Số tiền thanh toán phải lớn hơn 0');
    }
    if (!options.orderId) {
      throw new Error('Mã đơn hàng (orderId) không được để trống');
    }
    return this.transport.invoke<PaymentResult>('payment.requestPayment', options);
  }

  /**
   * Tra cứu trạng thái giao dịch
   */
  public async checkTransaction(transactionId: string): Promise<PaymentResult> {
    return this.transport.invoke<PaymentResult>('payment.checkTransaction', { transactionId });
  }
}
