import React, { useState, useEffect } from 'react';
import { MiniAppEntity } from './types';
import { BuilderView } from './views/BuilderView';
import { AdminPortalView } from './views/AdminPortalView';
import { defaultCoffeeShopApp } from './templates/coffeeShopTemplate';
import { LayoutDashboard, ShieldCheck, Sparkles, Plus, Loader2 } from 'lucide-react';

export const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'BUILDER' | 'ADMIN'>('ADMIN');
  const [apps, setApps] = useState<MiniAppEntity[]>([]);
  const [currentApp, setCurrentApp] = useState<MiniAppEntity | null>(null);
  const [loading, setLoading] = useState<boolean>(true);

  const [loadError, setLoadError] = useState('');

  // Fetch all apps from Registry API
  const fetchApps = async () => {
    try {
      setLoading(true);
      setLoadError('');
      const res = await fetch('/api/v1/registry/apps');
      if (!res.ok) throw new Error('Không tải được danh sách Mini App');
      if (res.ok) {
        const data: MiniAppEntity[] = await res.json();
        for (const app of data) {
          app.draftSchema ||= app.versions?.find(v => v.version === app.activePublishedVersion)?.schema;
        }
        setApps(data);
        setCurrentApp(previous => data.find(a => a.id === previous?.id) || data[0] || null);
      }
    } catch (err) {
      setLoadError(err instanceof Error ? err.message : 'Không kết nối được backend');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchApps();
  }, []);

  // Save Draft (create if new, update if exists)
  const handleSaveDraft = async (appToSave: MiniAppEntity) => {
    // Check if app already exists in registry
    const exists = apps.some((a) => a.id === appToSave.id);

    if (!exists) {
      // POST create
      const res = await fetch('/api/v1/registry/apps', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          id: appToSave.id,
          name: appToSave.name,
          description: appToSave.description,
          icon: appToSave.icon,
          category: appToSave.category,
          runtimeType: appToSave.runtimeType,
          capabilities: appToSave.capabilities,
          draftSchema: appToSave.draftSchema,
        }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'Lỗi khi tạo mới Mini App');
      }

      const saved = await res.json();
      setCurrentApp(saved);
      await fetchApps();
    } else {
      // PUT update
      const res = await fetch(`/api/v1/registry/apps/${appToSave.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: appToSave.name,
          description: appToSave.description,
          icon: appToSave.icon,
          category: appToSave.category,
          capabilities: appToSave.capabilities,
          draftSchema: appToSave.draftSchema,
        }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'Lỗi khi cập nhật bản thảo');
      }

      const updated = await res.json();
      setCurrentApp(updated);
      await fetchApps();
    }
  };

  const handleUploadVersion = async (appId: string, version: string, notes: string) => {
    const res = await fetch(`/api/v1/registry/apps/${appId}/versions`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ version, notes }),
    });
    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.message || 'Lỗi khi upload phiên bản');
    }
    await fetchApps();
  };

  // Create new blank or coffee shop draft
  const handleCreateNewApp = () => {
    const newId = `mini_app_${Date.now().toString().slice(-4)}`;
    const newApp: MiniAppEntity = {
      id: newId,
      name: 'Ứng Dụng Mới',
      description: 'Mô tả ngắn gọn về ứng dụng...',
      icon: 'sparkles',
      category: 'General',
      tenantId: 'tenant_001',
      runtimeType: 'schema',
      status: 'DRAFT',
      capabilities: ['navigation.close'],
      isAsset: false,
      draftSchema: {
        schemaVersion: 1,
        pages: [
          {
            id: 'home',
            title: 'Trang Chủ',
            components: [
              {
                id: 'txt_welcome',
                type: 'text',
                props: { value: 'Chào mừng quý khách!', variant: 'h2' },
              },
            ],
          },
        ],
      },
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    setCurrentApp(newApp);
    setActiveTab('BUILDER');
  };

  // Fallback initial app if none exist
  const activeApp =
    currentApp ||
    (apps.length > 0
      ? apps[0]
      : ({
          ...defaultCoffeeShopApp,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        } as MiniAppEntity));

  return (
    <div className="flex flex-col h-screen w-screen bg-slate-950 text-slate-100 overflow-hidden font-sans">
      {/* Top Application Header */}
      <header className="min-h-14 bg-slate-900 border-b border-slate-800 px-4 py-3 flex flex-wrap gap-3 items-center justify-between flex-shrink-0 z-20">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-amber-500 to-indigo-600 flex items-center justify-center font-black text-slate-950 text-base shadow-lg shadow-amber-500/20">
            S
          </div>
          <div>
            <h1 className="text-sm font-bold tracking-tight text-white flex items-center gap-2">
              Mini App Demo
              <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/30">
                Demo
              </span>
            </h1>
          </div>
        </div>

        {/* View Switcher Tabs */}
        <div className="flex items-center bg-slate-950 p-1 rounded-2xl whitespace-nowrap border border-slate-800">
          <button
            onClick={() => setActiveTab('BUILDER')}
            className={`flex items-center gap-2 px-4 py-1.5 rounded-xl text-xs font-semibold transition-all ${
              activeTab === 'BUILDER'
                ? 'bg-amber-500 text-slate-950 shadow-md font-bold'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <LayoutDashboard className="w-3.5 h-3.5" />
            <span>Thiết kế Schema</span>
          </button>

          <button
            onClick={() => setActiveTab('ADMIN')}
            className={`flex items-center gap-2 px-4 py-1.5 rounded-xl text-xs font-semibold transition-all ${
              activeTab === 'ADMIN'
                ? 'bg-indigo-600 text-white shadow-md font-bold'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Quản lý Mini App</span>
          </button>
        </div>

        {/* Quick App Select dropdown */}
        <div className={`items-center gap-2 ${activeTab === 'BUILDER' ? 'flex' : 'hidden'}`}>
          {apps.length > 0 && (
            <select
              value={activeApp.id}
              onChange={(e) => {
                const found = apps.find((a) => a.id === e.target.value);
                if (found) setCurrentApp(found);
              }}
              className="max-w-60 bg-slate-950 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-slate-200 outline-none"
            >
              {apps.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name} ({a.status})
                </option>
              ))}
            </select>
          )}

          <button
            onClick={handleCreateNewApp}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-xl text-xs font-semibold border border-slate-700 transition-all"
            title="Tạo mới Mini App"
          >
            <Plus className="w-3.5 h-3.5 text-amber-400" />
            <span>Tạo Mới</span>
          </button>
        </div>
      </header>

      {loadError && <div role="alert" className="p-3 text-red-300 bg-red-500/10">{loadError}. Kiểm tra backend ở cổng 3000. <button onClick={() => void fetchApps()} className="underline">Thử lại</button></div>}
      {/* Main Body */}
      {loading && apps.length === 0 ? (
        <div className="flex-1 flex flex-col items-center justify-center gap-3 text-slate-400">
          <Loader2 className="w-8 h-8 animate-spin text-amber-500" />
          <span className="text-xs font-medium">Đang kết nối Registry Backend...</span>
        </div>
      ) : activeTab === 'BUILDER' ? (
        <BuilderView
          key={activeApp.id}
          currentApp={activeApp}
          onAppChange={(updated) => setCurrentApp(updated)}
          onSaveDraft={handleSaveDraft}
          onUploadVersion={handleUploadVersion}
        />
      ) : (
        <AdminPortalView onRefreshApps={fetchApps} apps={apps} />
      )}
    </div>
  );
};
