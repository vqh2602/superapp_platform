import React, { useState } from 'react';
import { useSDK } from '../context/SDKContext';
import { superApp } from '../sdk';
import { Bug, Trash2, Copy, Check, Clock, AlertTriangle, RefreshCcw } from 'lucide-react';

export const DebugCenter: React.FC = () => {
  const { logs, clearLogs, openRunner, setAccessToken, setRefreshToken } = useSDK();
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const copyLog = (log: any) => {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(JSON.stringify(log, null, 2));
      }
    } catch (_) {}
    setCopiedId(log.id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const simulateFailure = (type: 'timeout' | 'unauthorized' | 'permission_denied' | 'unsupported' | 'internal') => {
    openRunner({
      id: `sim_${type}`,
      category: 'H. Debug & Testing',
      title: `Simulate ${type.toUpperCase()}`,
      description: `Mô phỏng phản hồi lỗi "${type}" từ Flutter Native Bridge`,
      actionCode: 'debug.simulateFailure',
      hasParams: false,
      run: () => superApp.debug.simulateFailure(type),
    });
  };

  const simulateTokenExpired = () => {
    setAccessToken('EXPIRED_MOCK_TOKEN_INVALIDATED');
    setRefreshToken('EXPIRED_REFRESH_TOKEN');
    alert('Đã giả lập làm hỏng token Mini App. Các API gọi tiếp theo yêu cầu refresh token hoặc login lại.');
  };

  return (
    <div className="debug-center-container">
      {/* Simulation Controls */}
      <div className="simulation-toolbar">
        <div className="toolbar-header">
          <Bug size={16} />
          <span>MÔ PHỎNG SỰ CỐ (SIMULATION CONTROLS)</span>
        </div>
        <div className="sim-buttons-grid">
          <button className="sim-btn" onClick={() => simulateFailure('timeout')}>
            <Clock size={13} />
            <span>Simulate Timeout</span>
          </button>
          <button className="sim-btn" onClick={() => simulateFailure('unauthorized')}>
            <AlertTriangle size={13} />
            <span>Simulate Unauthorized</span>
          </button>
          <button className="sim-btn" onClick={() => simulateFailure('permission_denied')}>
            <AlertTriangle size={13} />
            <span>Simulate Denied</span>
          </button>
          <button className="sim-btn" onClick={() => simulateFailure('internal')}>
            <AlertTriangle size={13} />
            <span>Simulate Failure</span>
          </button>
          <button className="sim-btn" onClick={() => simulateFailure('unsupported')}>
            <AlertTriangle size={13} />
            <span>Simulate Unsupported</span>
          </button>
          <button className="sim-btn sim-btn-warning" onClick={simulateTokenExpired}>
            <RefreshCcw size={13} />
            <span>Simulate Token Expired</span>
          </button>
        </div>
      </div>

      {/* Bridge Request/Response Inspector */}
      <div className="inspector-card">
        <div className="card-header-bar">
          <div className="header-title-row">
            <h3 className="section-title">Bridge Inspector Logs</h3>
            <span className="count-pill">{logs.length} calls</span>
          </div>
          {logs.length > 0 && (
            <button className="text-btn text-danger" onClick={clearLogs}>
              <Trash2 size={14} />
              <span>Clear</span>
            </button>
          )}
        </div>

        <div className="log-entries-list">
          {logs.length === 0 ? (
            <div className="empty-hint">Chưa có lời gọi SDK nào được thực hiện trong phiên này.</div>
          ) : (
            logs.map((log) => {
              const isSuccess = log.status === 'success';
              return (
                <div key={log.id} className={`log-entry-item ${isSuccess ? 'log-success' : 'log-error'}`}>
                  <div className="log-entry-header">
                    <div className="log-left">
                      <span className={`method-badge ${isSuccess ? 'bg-success' : 'bg-danger'}`}>
                        {log.method}
                      </span>
                      <span className="log-time">{log.timestamp}</span>
                      <span className="log-duration">{log.executionTimeMs} ms</span>
                    </div>
                    <button
                      className="icon-btn-sm"
                      onClick={() => copyLog(log)}
                      title="Sao chép toàn bộ log"
                    >
                      {copiedId === log.id ? <Check size={14} color="#10B981" /> : <Copy size={14} />}
                    </button>
                  </div>

                  {log.params && Object.keys(log.params).length > 0 && (
                    <div className="log-subfield">
                      <span className="subfield-label">Params:</span>
                      <code className="subfield-code">{JSON.stringify(log.params)}</code>
                    </div>
                  )}

                  <div className="log-subfield">
                    <span className="subfield-label">{isSuccess ? 'Result:' : 'Error:'}</span>
                    <pre className="subfield-pre">
                      {JSON.stringify(isSuccess ? log.response : log.error, null, 2)}
                    </pre>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
};
