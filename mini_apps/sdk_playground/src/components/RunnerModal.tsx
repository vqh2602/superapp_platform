import React, { useState, useEffect } from 'react';
import { useSDK, RunnerConfig } from '../context/SDKContext';
import { X, Play, RefreshCw, Copy, Check, Clock, AlertCircle, CheckCircle2 } from 'lucide-react';

interface RunnerModalProps {
  config: RunnerConfig;
  onClose: () => void;
}

export const RunnerModal: React.FC<RunnerModalProps> = ({ config, onClose }) => {
  const { addLog } = useSDK();
  const [params, setParams] = useState<string>(
    config.defaultParams ? JSON.stringify(config.defaultParams, null, 2) : ''
  );
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [result, setResult] = useState<any>(null);
  const [error, setError] = useState<any>(null);
  const [execTime, setExecTime] = useState<number | null>(null);
  const [copied, setCopied] = useState<boolean>(false);

  useEffect(() => {
    // Auto-run once opened if it has no input params
    if (!config.hasParams) {
      handleRun();
    }
  }, []);

  const handleRun = async () => {
    setIsLoading(true);
    setResult(null);
    setError(null);
    setExecTime(null);
    const start = performance.now();

    let parsedParams: any = {};
    if (config.hasParams && params.trim()) {
      try {
        parsedParams = JSON.parse(params);
      } catch (err: any) {
        setIsLoading(false);
        setError({ code: 'INVALID_PARAMS', message: `JSON syntax error: ${err.message}` });
        return;
      }
    }

    try {
      const data = await config.run(parsedParams);
      const elapsed = Math.round(performance.now() - start);
      setExecTime(elapsed);
      setResult(data);
      addLog({
        method: config.actionCode,
        params: parsedParams,
        status: 'success',
        response: data,
        executionTimeMs: elapsed,
      });
    } catch (err: any) {
      const elapsed = Math.round(performance.now() - start);
      setExecTime(elapsed);
      setError(err);
      addLog({
        method: config.actionCode,
        params: parsedParams,
        status: 'error',
        error: err,
        executionTimeMs: elapsed,
      });
    } finally {
      setIsLoading(false);
    }
  };

  const copyToClipboard = () => {
    const payload = result || error;
    if (!payload) return;
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
      }
    } catch (_) {}
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div>
            <div className="modal-category">{config.category}</div>
            <h2 className="modal-title">{config.title}</h2>
            <code className="modal-code">{config.actionCode}</code>
          </div>
          <button className="icon-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <p className="modal-desc">{config.description}</p>

        {config.hasParams && (
          <div className="param-section">
            <label className="section-label">Input Parameters (JSON):</label>
            <textarea
              className="param-textarea"
              value={params}
              onChange={(e) => setParams(e.target.value)}
              rows={4}
              placeholder="{}"
            />
          </div>
        )}

        <div className="action-row">
          <button className="primary-btn" onClick={handleRun} disabled={isLoading}>
            {isLoading ? (
              <>
                <RefreshCw size={16} className="spin" />
                <span>Đang thực thi...</span>
              </>
            ) : (
              <>
                <Play size={16} />
                <span>{result || error ? 'Chạy lại (Retry)' : 'Gọi SDK (Execute)'}</span>
              </>
            )}
          </button>

          {(result || error) && (
            <button className="secondary-btn" onClick={copyToClipboard} title="Copy JSON">
              {copied ? <Check size={16} color="#10B981" /> : <Copy size={16} />}
              <span>{copied ? 'Đã sao chép' : 'Copy JSON'}</span>
            </button>
          )}

          {execTime !== null && (
            <div className="exec-time-badge">
              <Clock size={14} />
              <span>{execTime} ms</span>
            </div>
          )}
        </div>

        {/* Response Viewer */}
        <div className="response-section">
          <div className="response-header">
            <span className="section-label">Response output:</span>
            {result && (
              <span className="badge badge-success">
                <CheckCircle2 size={13} /> Success
              </span>
            )}
            {error && (
              <span className="badge badge-error">
                <AlertCircle size={13} /> {error.code || 'Error'}
              </span>
            )}
          </div>

          <pre className={`json-viewer ${error ? 'json-viewer-error' : ''}`}>
            {isLoading && <span className="loading-text">Chờ phản hồi từ Flutter Bridge...</span>}
            {!isLoading && result && JSON.stringify(result, null, 2)}
            {!isLoading && error && JSON.stringify(error, null, 2)}
            {!isLoading && !result && !error && <span className="placeholder-text">Nhấn nút bên trên để thực thi action.</span>}
          </pre>
        </div>
      </div>
    </div>
  );
};
