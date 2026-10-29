import { MockStateStore } from '../store.js';
import { MockPaymentOrder, MockPaymentResult } from '../types.js';

export type PaymentApprovalHook = (order: MockPaymentOrder) => Promise<boolean>;

export class PaymentMockHandler {
  private approvalHook?: PaymentApprovalHook;

  constructor(private store: MockStateStore) {}

  public setApprovalHook(hook?: PaymentApprovalHook): void {
    this.approvalHook = hook;
  }

  public async requestPayment(payload: {
    orderId?: string;
    amount?: number;
    description?: string;
    currency?: string;
    appId?: string;
  }): Promise<MockPaymentResult> {
    const amount = Number(payload.amount) || 0;
    const orderId = payload.orderId || `ORD_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;

    const order: MockPaymentOrder = {
      orderId,
      amount,
      description: payload.description || 'Thanh toán dịch vụ Mini App',
      extraData: { currency: payload.currency || 'VND' },
    };

    // If manual approval hook is attached from Simulator UI
    if (this.approvalHook) {
      const approved = await this.approvalHook(order);
      if (!approved) {
        throw {
          code: 'USER_CANCELLED',
          message: 'Người dùng đã huỷ giao dịch thanh toán',
        };
      }
    }

    // Check balance
    const user = this.store.getUser();
    if (user.walletBalance < amount) {
      throw {
        code: 'INSUFFICIENT_FUNDS',
        message: `Số dư ví SuperApp Pay (${user.walletBalance.toLocaleString('vi-VN')} đ) không đủ để thanh toán ${amount.toLocaleString('vi-VN')} đ`,
      };
    }

    // Deduct balance
    this.store.deductBalance(amount);

    const transactionId = `TXN_${Date.now()}_${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
    const result: MockPaymentResult = {
      status: 'SUCCESS',
      transactionId,
      orderId,
      amount,
      timestamp: Date.now(),
      paymentMethod: 'SUPERAPP_WALLET',
      message: 'Thanh toán thành công qua Ví SuperApp',
    };

    this.store.addTransaction(result);
    return result;
  }

  public async createOrder(payload: {
    amount: number;
    description?: string;
    currency?: string;
  }): Promise<{ orderId: string; amount: number; currency: string; status: string }> {
    const orderId = `ORD_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;
    return {
      orderId,
      amount: Number(payload.amount) || 0,
      currency: payload.currency || 'VND',
      status: 'PENDING',
    };
  }
}
