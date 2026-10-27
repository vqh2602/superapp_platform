import React, { useCallback, useEffect, useState } from 'react';
import { Loader2, RefreshCw } from 'lucide-react';
import { MiniAppEntity } from './types';
import { AdminPortalView } from './views/AdminPortalView';

export const App: React.FC = () => {
  const [apps, setApps] = useState<MiniAppEntity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const fetchApps = useCallback(async () => {
    setError('');
    try {
      const response = await fetch('/api/v1/registry/apps');
      if (!response.ok) throw new Error('Không tải được danh sách Mini App');
      setApps(await response.json());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không kết nối được backend');
      throw err;
    } finally { setLoading(false); }
  }, []);
  useEffect(() => { void fetchApps().catch(() => undefined); }, [fetchApps]);

  return <div className="flex flex-col h-screen bg-slate-950 text-slate-100 font-sans">
    <header className="border-b border-slate-800 bg-slate-900 px-6 py-4 flex items-center justify-between gap-4">
      <div className="flex items-center gap-3"><div className="w-9 h-9 rounded-xl bg-indigo-500 flex items-center justify-center font-bold">S</div>
        <div><h1 className="font-bold">Mini App Manager</h1><p className="text-xs text-slate-400">Super App · Demo backend</p></div></div>
      <button className="flex items-center gap-2 text-sm text-slate-300" onClick={() => void fetchApps().catch(() => undefined)}><RefreshCw size={16} />Làm mới</button>
    </header>
    {error && <div role="alert" className="p-4 text-red-300 bg-red-500/10">{error}. Kiểm tra backend ở cổng 3000.</div>}
    {loading ? <div className="flex-1 flex items-center justify-center gap-3 text-slate-400"><Loader2 className="animate-spin" />Đang tải Mini App…</div>
      : <AdminPortalView apps={apps} onRefreshApps={fetchApps} />}
  </div>;
};
