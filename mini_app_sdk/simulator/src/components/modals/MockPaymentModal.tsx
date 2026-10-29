import React from 'react';
import { CheckCircle2, ShieldCheck, Wallet, X } from 'lucide-react';
import { useSimulator } from '../../context/SimulatorContext.js';

export const MockPaymentModal: React.FC = () => {
  const { pendingPayment, resolvePayment, user } = useSimulator();

  if (!pendingPayment) return null;

  const { order } = pendingPayment;
  const isBalanceEnough = user.walletBalance >= order.amount;

  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.6)',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'flex-end',
        zIndex: 100,
        animation: 'fadeIn 0.2s ease',
      }}
    >
      <div
        style={{
          backgroundColor: '#ffffff',
          borderTopLeftRadius: 24,
          borderTopRightRadius: 24,
          padding: 20,
          color: '#0f172a',
          boxShadow: '0 -4px 20px rgba(0, 0, 0, 0.15)',
        }}
      >
        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <ShieldCheck size={20} color="#0068FF" />
            <span style={{ fontWeight: 700, fontSize: 16 }}>SuperApp Pay</span>
          </div>
          <button
            onClick={() => resolvePayment(false)}
            style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}
          >
            <X size={18} color="#64748b" />
          </button>
        </div>

        {/* Amount */}
        <div style={{ textAlign: 'center', margin: '12px 0 20px' }}>
          <div style={{ fontSize: 13, color: '#64748b' }}>Tổng tiền thanh toán</div>
          <div style={{ fontSize: 28, fontWeight: 800, color: '#0068FF' }}>
            {order.amount.toLocaleString('vi-VN')} đ
          </div>
          <div style={{ fontSize: 13, fontWeight: 500, color: '#334155', marginTop: 4 }}>
            {order.description || 'Thanh toán dịch vụ Mini App'}
          </div>
        </div>

        {/* Payment Source */}
        <div
          style={{
            backgroundColor: '#f8fafc',
            borderRadius: 12,
            padding: 12,
            marginBottom: 20,
            border: '1px solid #e2e8f0',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: 8,
                  backgroundColor: '#dbeafe',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Wallet size={20} color="#0068FF" />
              </div>
              <div>
                <div style={{ fontWeight: 600, fontSize: 14 }}>Ví điện tử SuperApp</div>
                <div style={{ fontSize: 12, color: isBalanceEnough ? '#10b981' : '#ef4444' }}>
                  Số dư: {user.walletBalance.toLocaleString('vi-VN')} đ
                  {!isBalanceEnough && ' (Không đủ số dư)'}
                </div>
              </div>
            </div>
            <CheckCircle2 size={18} color="#0068FF" />
          </div>
        </div>

        {/* Actions */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <button
            onClick={() => resolvePayment(true)}
            disabled={!isBalanceEnough}
            style={{
              padding: '14px',
              backgroundColor: isBalanceEnough ? '#0068FF' : '#94a3b8',
              color: 'white',
              border: 'none',
              borderRadius: 12,
              fontWeight: 700,
              fontSize: 15,
              cursor: isBalanceEnough ? 'pointer' : 'not-allowed',
            }}
          >
            Xác nhận thanh toán
          </button>
          <button
            onClick={() => resolvePayment(false)}
            style={{
              padding: '12px',
              backgroundColor: 'transparent',
              color: '#64748b',
              border: 'none',
              borderRadius: 12,
              fontWeight: 600,
              fontSize: 14,
              cursor: 'pointer',
            }}
          >
            Huỷ giao dịch
          </button>
        </div>
      </div>
    </div>
  );
};
