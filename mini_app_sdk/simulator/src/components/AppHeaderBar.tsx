import React from 'react';
import { ArrowLeft, MoreHorizontal, RotateCw, X } from 'lucide-react';
import { useSimulator } from '../context/SimulatorContext.js';

export const AppHeaderBar: React.FC<{ title?: string }> = ({ title = 'Mini App' }) => {
  const { reloadIframe, sendEventToMiniApp } = useSimulator();

  return (
    <div
      style={{
        height: 48,
        padding: '0 12px',
        backgroundColor: '#ffffff',
        borderBottom: '1px solid #e2e8f0',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        color: '#0f172a',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <button
          onClick={() => sendEventToMiniApp('onNavigateBack', {})}
          title="Back"
          style={{
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            padding: 4,
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <ArrowLeft size={18} color="#0f172a" />
        </button>
        <span
          style={{
            fontSize: 15,
            fontWeight: 600,
            maxWidth: 160,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {title}
        </span>
      </div>

      {/* Capsule Menu */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          backgroundColor: '#f1f5f9',
          border: '1px solid #cbd5e1',
          borderRadius: 20,
          padding: '2px 6px',
          gap: 6,
        }}
      >
        <button
          onClick={reloadIframe}
          title="Tải lại Mini App"
          style={{
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            padding: 2,
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <RotateCw size={13} color="#475569" />
        </button>
        <div style={{ width: 1, height: 12, backgroundColor: '#cbd5e1' }} />
        <button
          title="Menu"
          style={{
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            padding: 2,
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <MoreHorizontal size={14} color="#475569" />
        </button>
        <div style={{ width: 1, height: 12, backgroundColor: '#cbd5e1' }} />
        <button
          onClick={() => alert('Đóng Mini App - Trở về màn hình chính SuperApp')}
          title="Đóng Mini App"
          style={{
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            padding: 2,
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <X size={14} color="#475569" />
        </button>
      </div>
    </div>
  );
};
