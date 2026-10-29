import React, { useCallback, useEffect, useState } from 'react';
import { AlertCircle, CheckCircle2, Loader2, RefreshCw, Server, WifiOff } from 'lucide-react';
import { MiniAppEntity } from './types';
import { AdminPortalView } from './views/AdminPortalView';
import { buildApiUrl, DEFAULT_ENDPOINT, getSavedEndpoint, LOCAL_ENDPOINT, normalizeEndpoint, saveEndpoint } from './api';

export const App: React.FC = () => {
  const [endpoint, setEndpoint] = useState<string>(() => getSavedEndpoint());
  const [inputEndpoint, setInputEndpoint] = useState<string>(() => getSavedEndpoint());
  const [apps, setApps] = useState<MiniAppEntity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [connected, setConnected] = useState(false);

  const fetchApps = useCallback(async (activeEndpoint?: string) => {
    const targetBase = activeEndpoint !== undefined ? normalizeEndpoint(activeEndpoint) : endpoint;
    setLoading(true);
    setError('');
    try {
      const url = buildApiUrl('/api/v1/registry/apps', targetBase);
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`Máy chủ trả về HTTP ${response.status}: ${response.statusText}`);
      }
      const data = await response.json();
      if (!Array.isArray(data)) {
        throw new Error('Định dạng dữ liệu máy chủ không hợp lệ');
      }
      setApps(data);
      setConnected(true);
    } catch (err) {
      setConnected(false);
      const msg = err instanceof Error ? err.message : 'Không kết nối được backend';
      setError(`${msg} (Endpoint: ${targetBase || 'proxy cục bộ'})`);
    } finally {
      setLoading(false);
    }
  }, [endpoint]);

  const handleApplyEndpoint = (newUrl: string) => {
    const clean = normalizeEndpoint(newUrl);
    saveEndpoint(clean);
    setEndpoint(clean);
    setInputEndpoint(clean);
    void fetchApps(clean);
  };

  useEffect(() => {
    void fetchApps(endpoint);
  }, []); // run on initial mount

  return (
    <div className="flex flex-col h-screen bg-slate-950 text-slate-100 font-sans">
      <header className="border-b border-slate-800 bg-slate-900 px-4 md:px-6 py-3 flex flex-wrap items-center justify-between gap-3">
        {/* Brand */}
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-indigo-600 to-violet-500 flex items-center justify-center font-bold text-white shadow-md shadow-indigo-500/20">
            S
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="font-bold text-base leading-tight">Mini App Manager</h1>
              <span className="text-[10px] uppercase font-semibold px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                Web Admin
              </span>
            </div>
            <p className="text-xs text-slate-400">SuperApp Platform CMS</p>
          </div>
        </div>

        {/* Endpoint Input Bar */}
        <div className="flex-1 max-w-2xl min-w-[280px]">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleApplyEndpoint(inputEndpoint);
            }}
            className="flex items-center gap-2 bg-slate-950 border border-slate-700 rounded-lg p-1 text-sm focus-within:border-indigo-400 transition"
          >
            <div className="pl-2 text-slate-400 flex items-center gap-1.5 shrink-0 text-xs font-medium">
              <Server size={14} className="text-indigo-400" />
              <span className="hidden sm:inline">Endpoint:</span>
            </div>
            <input
              type="text"
              value={inputEndpoint}
              onChange={(e) => setInputEndpoint(e.target.value)}
              placeholder="https://superappplatfrom.alwaysdata.net"
              className="w-full bg-transparent text-xs sm:text-sm text-slate-100 placeholder-slate-500 outline-none px-1"
              title="Nhập URL Backend API Registry"
            />
            <button
              type="submit"
              disabled={loading}
              className="shrink-0 px-3 py-1 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white rounded text-xs font-semibold flex items-center gap-1 transition"
            >
              {loading ? <Loader2 size={12} className="animate-spin" /> : null}
              Kết nối
            </button>
          </form>

          {/* Quick presets & Status */}
          <div className="flex items-center justify-between text-[11px] text-slate-400 mt-1 px-1">
            <div className="flex items-center gap-2">
              <span>Gợi ý:</span>
              <button
                type="button"
                onClick={() => handleApplyEndpoint(DEFAULT_ENDPOINT)}
                className={`hover:text-indigo-300 underline decoration-dotted transition ${
                  endpoint === DEFAULT_ENDPOINT ? 'text-indigo-400 font-semibold' : ''
                }`}
              >
                🌐 Alwaysdata (Cloud)
              </button>
              <span>·</span>
              <button
                type="button"
                onClick={() => handleApplyEndpoint(LOCAL_ENDPOINT)}
                className={`hover:text-indigo-300 underline decoration-dotted transition ${
                  endpoint === LOCAL_ENDPOINT ? 'text-indigo-400 font-semibold' : ''
                }`}
              >
                💻 Localhost (3000)
              </button>
            </div>

            <div className="flex items-center gap-1.5">
              {loading ? (
                <span className="flex items-center gap-1 text-amber-400">
                  <Loader2 size={11} className="animate-spin" /> Đang kết nối…
                </span>
              ) : connected ? (
                <span className="flex items-center gap-1 text-emerald-400 font-medium">
                  <CheckCircle2 size={11} /> Đã kết nối ({apps.length} apps)
                </span>
              ) : (
                <span className="flex items-center gap-1 text-rose-400 font-medium">
                  <AlertCircle size={11} /> Mất kết nối
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-2 shrink-0">
          <button
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-700 bg-slate-800 hover:bg-slate-700 text-xs font-medium text-slate-200 transition"
            onClick={() => void fetchApps(endpoint)}
            disabled={loading}
            title="Tải lại dữ liệu"
          >
            <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
            <span className="hidden sm:inline">Làm mới</span>
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      {error && (
        <div className="bg-red-950/40 border-b border-red-800/60 p-4 text-xs sm:text-sm text-red-200">
          <div className="max-w-4xl mx-auto flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <WifiOff className="text-red-400 shrink-0" size={18} />
              <div>
                <strong>Lỗi kết nối Endpoint:</strong> {error}
                <p className="text-xs text-red-300/80 mt-0.5">
                  Vui lòng kiểm tra lại URL endpoint ở thanh trên hoặc chọn preset Cloud / Localhost.
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={() => handleApplyEndpoint(DEFAULT_ENDPOINT)}
                className="px-2.5 py-1 bg-red-900/60 hover:bg-red-900 border border-red-700 rounded text-xs text-white"
              >
                Dùng Alwaysdata Cloud
              </button>
              <button
                onClick={() => void fetchApps(endpoint)}
                className="px-2.5 py-1 bg-indigo-600 hover:bg-indigo-500 rounded text-xs text-white"
              >
                Thử lại
              </button>
            </div>
          </div>
        </div>
      )}

      {loading && apps.length === 0 ? (
        <div className="flex-1 flex flex-col items-center justify-center gap-3 text-slate-400 p-6">
          <Loader2 className="animate-spin text-indigo-400" size={32} />
          <p className="text-sm">Đang tải danh sách Mini App từ {endpoint || 'backend'}…</p>
        </div>
      ) : (
        <AdminPortalView apps={apps} onRefreshApps={() => fetchApps(endpoint)} />
      )}
    </div>
  );
};
