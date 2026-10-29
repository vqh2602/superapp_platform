import React from 'react';
import { KeyRound, LogOut, ShieldCheck, UserCheck } from 'lucide-react';
import { useSimulator } from '../../context/SimulatorContext.js';

export const AuthMockTab: React.FC = () => {
  const { user, setUser, setUserPreset, mockEngine, sendEventToMiniApp } = useSimulator();
  const session = mockEngine.store.getSession();

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16, fontSize: 13, color: '#f1f5f9' }}>
      {/* Preset Personas */}
      <div>
        <div style={{ fontWeight: 600, marginBottom: 8, color: '#94a3b8' }}>Chọn tài khoản mẫu (Persona):</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <button
            onClick={() => setUserPreset('standard')}
            style={{
              padding: 8,
              backgroundColor: user.id === 'user_std_001' ? '#0284c7' : '#1e293b',
              border: '1px solid #334155',
              borderRadius: 6,
              color: '#ffffff',
              cursor: 'pointer',
              fontWeight: 500,
              fontSize: 12,
            }}
          >
            👤 Khách hàng chuẩn
          </button>
          <button
            onClick={() => setUserPreset('vip')}
            style={{
              padding: 8,
              backgroundColor: user.id === 'user_vip_888' ? '#7c3aed' : '#1e293b',
              border: '1px solid #334155',
              borderRadius: 6,
              color: '#ffffff',
              cursor: 'pointer',
              fontWeight: 500,
              fontSize: 12,
            }}
          >
            💎 VIP Diamond (50tr)
          </button>
          <button
            onClick={() => setUserPreset('lowBalance')}
            style={{
              padding: 8,
              backgroundColor: user.id === 'user_low_002' ? '#d97706' : '#1e293b',
              border: '1px solid #334155',
              borderRadius: 6,
              color: '#ffffff',
              cursor: 'pointer',
              fontWeight: 500,
              fontSize: 12,
            }}
          >
            ⚠️ Số dư thấp (15k)
          </button>
          <button
            onClick={() => setUserPreset('unverified')}
            style={{
              padding: 8,
              backgroundColor: user.id === 'user_guest_999' ? '#dc2626' : '#1e293b',
              border: '1px solid #334155',
              borderRadius: 6,
              color: '#ffffff',
              cursor: 'pointer',
              fontWeight: 500,
              fontSize: 12,
            }}
          >
            ❓ Khách vãng lai
          </button>
        </div>
      </div>

      {/* User details card */}
      <div
        style={{
          backgroundColor: '#0f172a',
          borderRadius: 8,
          padding: 12,
          border: '1px solid #1e293b',
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <img
            src={user.avatarUrl}
            alt="Avatar"
            style={{ width: 44, height: 44, borderRadius: '50%', objectFit: 'cover' }}
          />
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: 700, fontSize: 14 }}>{user.name}</div>
            <div style={{ color: '#94a3b8', fontSize: 12 }}>{user.phone || 'Chưa cung cấp SĐT'}</div>
          </div>
          {user.isVerified && (
            <span
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 4,
                backgroundColor: '#064e3b',
                color: '#34d399',
                padding: '2px 8px',
                borderRadius: 12,
                fontSize: 11,
                fontWeight: 600,
              }}
            >
              <ShieldCheck size={12} /> Đã xác thực
            </span>
          )}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, fontSize: 12, marginTop: 4 }}>
          <div>
            <span style={{ color: '#94a3b8' }}>Vai trò:</span>{' '}
            <span style={{ fontWeight: 600, color: '#38bdf8' }}>{user.role}</span>
          </div>
          <div>
            <span style={{ color: '#94a3b8' }}>Số dư ví:</span>{' '}
            <span style={{ fontWeight: 600, color: '#10b981' }}>
              {user.walletBalance.toLocaleString('vi-VN')} đ
            </span>
          </div>
        </div>
      </div>

      {/* Token Session */}
      <div
        style={{
          backgroundColor: '#0f172a',
          borderRadius: 8,
          padding: 12,
          border: '1px solid #1e293b',
          display: 'flex',
          flexDirection: 'column',
          gap: 8,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 600, color: '#38bdf8' }}>
          <KeyRound size={16} /> Phiên Access Token
        </div>
        {session ? (
          <div>
            <div style={{ fontSize: 11, color: '#94a3b8', marginBottom: 2 }}>Mã Token:</div>
            <div
              style={{
                fontFamily: 'monospace',
                fontSize: 11,
                backgroundColor: '#020617',
                padding: 6,
                borderRadius: 4,
                color: '#facc15',
                wordBreak: 'break-all',
              }}
            >
              {session.accessToken}
            </div>
            <div style={{ fontSize: 11, color: '#94a3b8', marginTop: 4 }}>
              Hết hạn sau: {session.expiresIn}s ({session.tokenType})
            </div>
          </div>
        ) : (
          <div style={{ color: '#ef4444', fontSize: 12 }}>Phiên đã hết hạn hoặc chưa đăng nhập</div>
        )}

        <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
          <button
            onClick={() => {
              mockEngine.store.createSession();
              sendEventToMiniApp('onAuthStatusChange', { loggedIn: true });
            }}
            style={{
              flex: 1,
              padding: '6px 10px',
              backgroundColor: '#0369a1',
              color: 'white',
              border: 'none',
              borderRadius: 6,
              cursor: 'pointer',
              fontWeight: 600,
              fontSize: 12,
            }}
          >
            Làm mới Token
          </button>
          <button
            onClick={() => {
              mockEngine.store.clearSession();
              sendEventToMiniApp('onAuthStatusChange', { loggedIn: false });
            }}
            style={{
              padding: '6px 10px',
              backgroundColor: '#334155',
              color: '#f87171',
              border: 'none',
              borderRadius: 6,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              fontSize: 12,
            }}
          >
            <LogOut size={13} /> Đăng xuất
          </button>
        </div>
      </div>
    </div>
  );
};
