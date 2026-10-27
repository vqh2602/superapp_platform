import { MockStateStore } from '../store.js';
import { MockPaymentOrder, MockPaymentResult } from '../types.js';

export type PaymentDecisionResolver = (order: MockPaymentOrder) => Promise<boolean>;

export class PaymentMockHandler {
  private manualDecisionResolver?: PaymentDecisionResolver;

  constructor(
    private store: MockStateStore,
    private autoApprove: boolean = true
  ) {}

  public setManualDecisionResolver(resolver: PaymentDecisionResolver): void {
    this.manualDecisionResolver = resolver;
  }

  public setAutoApprove(val: boolean): void {
    this.autoApprove = val;
  }

  public async requestPayment(order: MockPaymentOrder): Promise<MockPaymentResult> {
    if (!order.amount || order.amount <= 0) {
      throw {
        code: 'INVALID_AMOUNT',
        message: 'Payment amount must be greater than 0',
      };
    }

    if (!order.orderId) {
      throw {
        code: 'INVALID_ORDER_ID',
        message: 'Order ID is required',
      };
    }

    // Check user balance
    const currentBalance = this.store.getBalance();
    if (currentBalance < order.amount) {
      const failedResult: MockPaymentResult = {
        transactionId: `tx_failed_${Date.now()}`,
        orderId: order.orderId,
        status: 'FAILED',
        amount: order.amount,
        timestamp: Date.now(),
        paymentMethod: 'SUPERAPP_WALLET',
        message: `Số dư ví SuperApp không đủ (${currentBalance.toLocaleString('vi-VN')} đ < ${order.amount.toLocaleString('vi-VN')} đ)`,
      };
      this.store.addTransaction(failedResult);
      throw {
        code: 'INSUFFICIENT_FUNDS',
        message: failedResult.message,
        details: failedResult,
      };
    }

    // Determine approval (either auto or manual prompt in simulator)
    let approved = this.autoApprove;
    if (this.manualDecisionResolver) {
      approved = await this.manualDecisionResolver(order);
    }

    if (!approved) {
      const cancelResult: MockPaymentResult = {
        transactionId: `tx_cancel_${Date.now()}`,
        orderId: order.orderId,
        status: 'CANCELLED',
        amount: order.amount,
        timestamp: Date.now(),
        paymentMethod: 'SUPERAPP_WALLET',
        message: 'Người dùng đã huỷ giao dịch thanh toán',
      };
      this.store.addTransaction(cancelResult);
      throw {
        code: 'USER_CANCELLED',
        message: cancelResult.message,
        details: cancelResult,
      };
    }

    // Deduct balance & record successful transaction
    this.store.deductBalance(order.amount);
    const successResult: MockPaymentResult = {
      transactionId: `tx_succ_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      orderId: order.orderId,
      status: 'SUCCESS',
      amount: order.amount,
      timestamp: Date.now(),
      paymentMethod: 'SUPERAPP_WALLET',
      message: 'Thanh toán thành công qua ví SuperApp',
    };
    this.store.addTransaction(successResult);
    return successResult;
  }

  public async checkTransaction(payload: { transactionId: string }): Promise<MockPaymentResult> {
    const tx = this.store.getTransaction(payload.transactionId);
    if (!tx) {
      throw {
        code: 'TRANSACTION_NOT_FOUND',
        message: `Không tìm thấy mã giao dịch: ${payload.transactionId}`,
      };
    }
    return tx;
  }
}
