import React from 'react';
import { CreditCard, PlusCircle, ToggleLeft, ToggleRight, Wallet } from 'lucide-react';
import { MockPaymentResult } from '@superapp/sdk-mock-engine';
import { useSimulator } from '../../context/SimulatorContext.js';

export const PaymentMockTab: React.FC = () => {
  const { user, setUser, manualPaymentMode, setManualPaymentMode, mockEngine } = useSimulator();
  const transactions = mockEngine.payment['store'].getTransactions();

  const handleTopUp = (amount: number) => {
    setUser({ walletBalance: user.walletBalance + amount });
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16, fontSize: 13, color: '#f1f5f9' }}>
      {/* Balance Card */}
      <div
        style={{
          background: 'linear-gradient(135deg, #0284c7 0%, #0369a1 100%)',
          borderRadius: 12,
          padding: 16,
          color: 'white',
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
          boxShadow: '0 4px 12px rgba(2, 132, 199, 0.25)',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, opacity: 0.9 }}>
            <Wallet size={16} /> Số dư Ví SuperApp
          </div>
          <span style={{ fontSize: 11, backgroundColor: 'rgba(255,255,255,0.2)', padding: '2px 8px', borderRadius: 10 }}>
            Mock
          </span>
        </div>

        <div style={{ fontSize: 26, fontWeight: 800 }}>
          {user.walletBalance.toLocaleString('vi-VN')} đ
        </div>

        <div>
          <div style={{ fontSize: 11, opacity: 0.8, marginBottom: 6 }}>Nạp tiền nhanh thử nghiệm:</div>
          <div style={{ display: 'flex', gap: 6 }}>
            <button
              onClick={() => handleTopUp(100000)}
              style={{
                flex: 1,
                padding: '4px 6px',
                backgroundColor: 'rgba(255,255,255,0.15)',
                border: '1px solid rgba(255,255,255,0.3)',
                borderRadius: 6,
                color: 'white',
                fontSize: 11,
                cursor: 'pointer',
                fontWeight: 600,
              }}
            >
              +100.000 đ
            </button>
            <button
              onClick={() => handleTopUp(500000)}
              style={{
                flex: 1,
                padding: '4px 6px',
                backgroundColor: 'rgba(255,255,255,0.15)',
                border: '1px solid rgba(255,255,255,0.3)',
                borderRadius: 6,
                color: 'white',
                fontSize: 11,
                cursor: 'pointer',
                fontWeight: 600,
              }}
            >
              +500.000 đ
            </button>
            <button
              onClick={() => handleTopUp(2000000)}
              style={{
                flex: 1,
                padding: '4px 6px',
                backgroundColor: 'rgba(255,255,255,0.15)',
                border: '1px solid rgba(255,255,255,0.3)',
                borderRadius: 6,
                color: 'white',
                fontSize: 11,
                cursor: 'pointer',
                fontWeight: 600,
              }}
            >
              +2.000.000 đ
            </button>
          </div>
        </div>
      </div>

      {/* Payment Confirmation Mode */}
      <div
        style={{
          backgroundColor: '#0f172a',
          borderRadius: 8,
          padding: 12,
          border: '1px solid #1e293b',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <div>
          <div style={{ fontWeight: 600 }}>Popup xác nhận thanh toán thủ công</div>
          <div style={{ fontSize: 11, color: '#94a3b8' }}>
            {manualPaymentMode
              ? 'Hiện Bottom Sheet trên Simulator để bấm Xác nhận / Huỷ'
              : 'Tự động duyệt thanh toán thành công ngay lập tức'}
          </div>
        </div>
        <button
          onClick={() => setManualPaymentMode(!manualPaymentMode)}
          style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
        >
          {manualPaymentMode ? (
            <ToggleRight size={28} color="#0284c7" />
          ) : (
            <ToggleLeft size={28} color="#64748b" />
          )}
        </button>
      </div>

      {/* Transaction History */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ fontWeight: 600, color: '#94a3b8' }}>Lịch sử giao dịch ({transactions.length}):</div>
        {transactions.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#64748b', padding: '20px 0', fontSize: 12 }}>
            Chưa có giao dịch thanh toán nào được thực hiện
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 220, overflowY: 'auto' }}>
            {transactions.map((tx: MockPaymentResult) => (
              <div
                key={tx.transactionId}
                style={{
                  backgroundColor: '#0f172a',
                  border: '1px solid #1e293b',
                  borderRadius: 6,
                  padding: 8,
                  fontSize: 12,
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <div>
                  <div style={{ fontWeight: 600 }}>{tx.orderId}</div>
                  <div style={{ fontSize: 11, color: '#94a3b8' }}>{tx.transactionId}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div
                    style={{
                      fontWeight: 700,
                      color:
                        tx.status === 'SUCCESS'
                          ? '#10b981'
                          : tx.status === 'CANCELLED'
                          ? '#f59e0b'
                          : '#ef4444',
                    }}
                  >
                    {tx.amount.toLocaleString('vi-VN')} đ
                  </div>
                  <div style={{ fontSize: 10, color: '#64748b' }}>{tx.status}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
