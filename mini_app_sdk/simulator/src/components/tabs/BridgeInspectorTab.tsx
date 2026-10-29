import React, { useState } from 'react';
import { CheckCircle2, ChevronDown, ChevronRight, Clock, Trash2, XCircle } from 'lucide-react';
import { useSimulator } from '../../context/SimulatorContext.js';
import { MockLogEntry } from '@vqh2602/sdk-mock-engine';

export const BridgeInspectorTab: React.FC = () => {
  const { logs, clearLogs } = useSimulator();
  const [selectedLog, setSelectedLog] = useState<MockLogEntry | null>(null);
  const [filterAction, setFilterAction] = useState<string>('');

  const filteredLogs = logs.filter((log) =>
    log.action.toLowerCase().includes(filterAction.toLowerCase())
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', gap: 12 }}>
      {/* Toolbar */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
        <input
          type="text"
          placeholder="Lọc bridge action (vd: auth, payment)..."
          value={filterAction}
          onChange={(e) => setFilterAction(e.target.value)}
          style={{
            flex: 1,
            padding: '6px 12px',
            borderRadius: 6,
            border: '1px solid #334155',
            backgroundColor: '#0f172a',
            color: '#f8fafc',
            fontSize: 13,
          }}
        />
        <button
          onClick={clearLogs}
          title="Xoá nhật ký"
          style={{
            padding: '6px 10px',
            backgroundColor: '#1e293b',
            border: '1px solid #334155',
            borderRadius: 6,
            color: '#94a3b8',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: 4,
            fontSize: 12,
          }}
        >
          <Trash2 size={14} /> Xoá
        </button>
      </div>

      {/* Logs Table / List */}
      <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 6 }}>
        {filteredLogs.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#64748b', padding: '40px 10px', fontSize: 13 }}>
            Chưa có cuộc gọi Bridge nào từ Mini App. Hãy thực hiện thao tác trong Mini App để theo dõi.
          </div>
        ) : (
          filteredLogs.map((log) => {
            const isSelected = selectedLog?.id === log.id;
            return (
              <div
                key={log.id}
                onClick={() => setSelectedLog(isSelected ? null : log)}
                style={{
                  padding: 10,
                  borderRadius: 8,
                  backgroundColor: isSelected ? '#1e293b' : '#0f172a',
                  border: `1px solid ${isSelected ? '#38bdf8' : '#1e293b'}`,
                  cursor: 'pointer',
                  fontSize: 12,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 6,
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    {log.success ? (
                      <CheckCircle2 size={14} color="#10b981" />
                    ) : (
                      <XCircle size={14} color="#ef4444" />
                    )}
                    <span style={{ fontWeight: 600, color: '#f1f5f9' }}>{log.action}</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: '#94a3b8' }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 2, fontSize: 11 }}>
                      <Clock size={11} /> {log.durationMs}ms
                    </span>
                    {isSelected ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                  </div>
                </div>

                {/* Expanded Details */}
                {isSelected && (
                  <div
                    style={{
                      marginTop: 6,
                      paddingTop: 8,
                      borderTop: '1px solid #334155',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: 8,
                    }}
                  >
                    <div>
                      <div style={{ color: '#94a3b8', fontSize: 11, marginBottom: 2 }}>Payload gửi đi:</div>
                      <pre
                        style={{
                          margin: 0,
                          padding: 8,
                          backgroundColor: '#020617',
                          borderRadius: 6,
                          fontSize: 11,
                          color: '#e2e8f0',
                          overflowX: 'auto',
                        }}
                      >
                        {JSON.stringify(log.payload, null, 2)}
                      </pre>
                    </div>

                    <div>
                      <div style={{ color: '#94a3b8', fontSize: 11, marginBottom: 2 }}>Kết quả phản hồi:</div>
                      <pre
                        style={{
                          margin: 0,
                          padding: 8,
                          backgroundColor: '#020617',
                          borderRadius: 6,
                          fontSize: 11,
                          color: log.success ? '#34d399' : '#f87171',
                          overflowX: 'auto',
                        }}
                      >
                        {JSON.stringify(log.success ? log.response : log.error, null, 2)}
                      </pre>
                    </div>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
