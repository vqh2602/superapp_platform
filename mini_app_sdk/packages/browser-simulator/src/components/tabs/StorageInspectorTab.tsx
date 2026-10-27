import React, { useState } from 'react';
import { Database, Plus, Trash2 } from 'lucide-react';
import { useSimulator } from '../../context/SimulatorContext.js';

export const StorageInspectorTab: React.FC = () => {
  const { mockEngine } = useSimulator();
  const [newKey, setNewKey] = useState('');
  const [newValue, setNewValue] = useState('');
  const [refreshKey, setRefreshKey] = useState(0);

  const storageMap = mockEngine.store.getStorage('mini_app_simulator');
  const entries: [string, string][] = Array.from(storageMap.entries());

  const handleAdd = () => {
    if (!newKey.trim()) return;
    mockEngine.store.setStorageItem('mini_app_simulator', newKey.trim(), newValue);
    setNewKey('');
    setNewValue('');
    setRefreshKey((k) => k + 1);
  };

  const handleDelete = (key: string) => {
    mockEngine.store.removeStorageItem('mini_app_simulator', key);
    setRefreshKey((k) => k + 1);
  };

  const handleClear = () => {
    mockEngine.store.clearStorage('mini_app_simulator');
    setRefreshKey((k) => k + 1);
  };

  return (
    <div key={refreshKey} style={{ display: 'flex', flexDirection: 'column', gap: 16, fontSize: 13, color: '#f1f5f9' }}>
      {/* Add New Key */}
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
        <div style={{ fontWeight: 600, color: '#38bdf8', display: 'flex', alignItems: 'center', gap: 6 }}>
          <Database size={16} /> Thêm Key vào bộ nhớ Mini App
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <input
            type="text"
            placeholder="Key (vd: cart_id)"
            value={newKey}
            onChange={(e) => setNewKey(e.target.value)}
            style={{
              flex: 1,
              padding: '6px 10px',
              backgroundColor: '#020617',
              border: '1px solid #334155',
              borderRadius: 6,
              color: 'white',
              fontSize: 12,
            }}
          />
          <input
            type="text"
            placeholder="Value"
            value={newValue}
            onChange={(e) => setNewValue(e.target.value)}
            style={{
              flex: 2,
              padding: '6px 10px',
              backgroundColor: '#020617',
              border: '1px solid #334155',
              borderRadius: 6,
              color: 'white',
              fontSize: 12,
            }}
          />
          <button
            onClick={handleAdd}
            style={{
              padding: '6px 12px',
              backgroundColor: '#0284c7',
              color: 'white',
              border: 'none',
              borderRadius: 6,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              fontSize: 12,
              fontWeight: 600,
            }}
          >
            <Plus size={14} /> Thêm
          </button>
        </div>
      </div>

      {/* Storage Entries List */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontWeight: 600, color: '#94a3b8' }}>Dữ liệu đã lưu ({entries.length}):</div>
        {entries.length > 0 && (
          <button
            onClick={handleClear}
            style={{
              background: 'none',
              border: 'none',
              color: '#ef4444',
              cursor: 'pointer',
              fontSize: 12,
              display: 'flex',
              alignItems: 'center',
              gap: 4,
            }}
          >
            <Trash2 size={13} /> Xoá toàn bộ
          </button>
        )}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 300, overflowY: 'auto' }}>
        {entries.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#64748b', padding: '30px 0', fontSize: 12 }}>
            Kho lưu trữ đang trống. Mini App có thể lưu qua `superApp.storage.setItem()`.
          </div>
        ) : (
          entries.map(([k, v]) => (
            <div
              key={k}
              style={{
                backgroundColor: '#0f172a',
                border: '1px solid #1e293b',
                borderRadius: 6,
                padding: '8px 10px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                gap: 8,
              }}
            >
              <div style={{ flex: 1, overflow: 'hidden' }}>
                <span style={{ fontWeight: 700, color: '#38bdf8', fontSize: 12 }}>{k}</span>
                <div
                  style={{
                    color: '#e2e8f0',
                    fontSize: 12,
                    fontFamily: 'monospace',
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {v}
                </div>
              </div>
              <button
                onClick={() => handleDelete(k)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, color: '#94a3b8' }}
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
