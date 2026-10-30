import { ITransport } from '../../transport/index.js';

export interface PaymentOrder {
  orderId: string;
  amount: number;
  description: string;
  partnerCode?: string;
  extraData?: Record<string, any>;
}

export interface PaymentResult {
  transactionId: string;
  orderId: string;
  status: 'SUCCESS' | 'FAILED' | 'CANCELLED' | string;
  amount: number;
  timestamp: number;
  paymentMethod: string;
  message: string;
}

export class PaymentModule {
  constructor(private transport: ITransport) {}

  /**
   * Tạo đơn hàng thanh toán
   */
  public async createOrder(data: {
    amount: number;
    description: string;
    partnerCode?: string;
    extraData?: Record<string, any>;
  }): Promise<PaymentOrder> {
    return this.transport.invoke<PaymentOrder>('payment.createOrder', data);
  }

  /**
   * Mở giao diện thanh toán native SuperApp
   */
  public async openCheckout(orderId: string): Promise<PaymentResult> {
    return this.transport.invoke<PaymentResult>('payment.openCheckout', { orderId });
  }

  /**
   * Kiểm tra trạng thái giao dịch thanh toán
   */
  public async checkStatus(transactionId: string): Promise<PaymentResult> {
    return this.transport.invoke<PaymentResult>('payment.checkStatus', { transactionId });
  }
}
