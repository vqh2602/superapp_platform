import React, { useEffect, useState } from 'react';
import { MiniAppEntity } from '../types';

interface Props {
  apps: MiniAppEntity[];
  onRefreshApps: () => Promise<void>;
}

async function request(path: string, method: string, body: unknown) {
  const response = await fetch(`/api/v1/registry/apps${path}`, {
    method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(Array.isArray(data.message) ? data.message.join(', ') : data.message || 'Không thể lưu');
  return data;
}

const inputClass = 'w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100';
const buttonClass = 'px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-sm font-semibold';

export const AdminPortalView: React.FC<Props> = ({ apps, onRefreshApps }) => {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const selectedApp = apps.find(app => app.id === selectedId) || (!creating ? apps[0] : undefined);

  return <div className="flex-1 overflow-auto p-6">
    <div className="flex justify-between items-center mb-6">
      <div><h2 className="text-xl font-bold">Quản lý Mini App</h2>
        <p className="text-sm text-slate-400 mt-1">Thông tin, quyền được cấp, phiên bản và ẩn/hiện trên Super App.</p></div>
      <button className={buttonClass} onClick={() => { setCreating(true); setSelectedId(null); }}>+ Thêm Mini App</button>
    </div>
    <div className="grid grid-cols-1 lg:grid-cols-[320px_1fr] gap-6 max-w-7xl mx-auto">
      <div className="space-y-2">
        {apps.length === 0 && <p className="text-sm text-slate-400">Chưa có Mini App. Thêm ứng dụng để bắt đầu.</p>}
        {apps.map(app => <button key={app.id} onClick={() => { setSelectedId(app.id); setCreating(false); }}
          className={`w-full text-left p-4 rounded-xl border ${selectedApp?.id === app.id ? 'border-indigo-500 bg-indigo-500/10' : 'border-slate-800 bg-slate-900'}`}>
          <div className="flex justify-between gap-2"><strong>{app.name}</strong><span className={app.status === 'PUBLISHED' ? 'text-emerald-400 text-xs' : 'text-slate-400 text-xs'}>{app.status === 'PUBLISHED' ? 'Đang hiện' : 'Đang ẩn'}</span></div>
          <div className="text-xs text-slate-400 mt-2">{app.id} · {app.runtimeType} · {app.activePublishedVersion || 'Chưa có phiên bản'}</div>
          <div className="text-xs text-slate-400 mt-1">{app.capabilities.length} quyền được cấp</div>
        </button>)}
      </div>
      {(creating || selectedApp) && <MiniAppEditor key={creating ? 'new' : selectedApp!.id} app={creating ? undefined : selectedApp}
        onSaved={async id => { await onRefreshApps(); setSelectedId(id); setCreating(false); }} />}
    </div>
  </div>;
};

function MiniAppEditor({ app, onSaved }: { app?: MiniAppEntity; onSaved: (id: string) => Promise<void> }) {
  const [id, setId] = useState('');
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('General');
  const [runtimeType, setRuntimeType] = useState<'schema' | 'web'>('schema');
  const [capabilities, setCapabilities] = useState('');
  const [version, setVersion] = useState('1.0.0');
  const [schema, setSchema] = useState('');
  const [entryUrl, setEntryUrl] = useState('');
  const [isAsset, setIsAsset] = useState(false);
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (!app) return;
    setId(app.id); setName(app.name); setDescription(app.description); setCategory(app.category);
    setRuntimeType(app.runtimeType); setCapabilities(app.capabilities.join('\n'));
    setEntryUrl(app.entryUrl || (app.runtimeType === 'schema' ? 'assets/mini_apps/schema_runtime/index.html' : ''));
    setIsAsset(app.entryUrl ? app.isAsset : app.runtimeType === 'schema');
    const latest = app.versions?.find(v => v.version === app.activePublishedVersion);
    setSchema(JSON.stringify(app.draftSchema || latest?.schema || { schemaVersion: 1, pages: [{ id: 'home', title: app.name, components: [] }] }, null, 2));
    const parts = (app.activePublishedVersion || '0.0.0').split('.').map(Number);
    setVersion(app.activePublishedVersion ? `${parts[0]}.${parts[1]}.${parts[2] + 1}` : '1.0.0');
  }, [app]);

  const run = async (action: () => Promise<void>, success: string) => {
    setBusy(true); setError(''); setMessage('');
    try { await action(); setMessage(success); } catch (err) { setError(err instanceof Error ? err.message : 'Thao tác thất bại'); }
    finally { setBusy(false); }
  };
  const saveMetadata = async () => {
    const data = { name, description, category, capabilities: [...new Set(capabilities.split(/[\n,]/).map(v => v.trim()).filter(Boolean))] };
    const saved = await request(app ? `/${app.id}` : '', app ? 'PUT' : 'POST', app ? data : { ...data, id, runtimeType });
    await onSaved(saved.id);
  };

  return <div className="space-y-6 min-w-0">
    {error && <div role="alert" className="p-3 rounded-lg bg-red-500/10 text-red-300">{error}</div>}
    {message && <div role="status" className="p-3 rounded-lg bg-emerald-500/10 text-emerald-300">{message}</div>}
    <form className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4" onSubmit={e => { e.preventDefault(); void run(saveMetadata, 'Đã lưu thông tin và quyền.'); }}>
      <h3 className="font-semibold">{app ? app.name : 'Thêm Mini App'}</h3>
      <fieldset disabled={busy} className="space-y-4">
        {!app && <><label className="block text-sm">ID<input required pattern="[a-z0-9_]{3,32}" value={id} onChange={e => setId(e.target.value)} className={inputClass} placeholder="coffee_shop" /></label>
          <label className="block text-sm">Loại Mini App<select className={inputClass} value={runtimeType} onChange={e => setRuntimeType(e.target.value as 'web' | 'schema')}><option value="schema">Schema JSON</option><option value="web">Web (URL)</option></select></label></>}
        <label className="block text-sm">Tên<input required maxLength={128} value={name} onChange={e => setName(e.target.value)} className={inputClass} /></label>
        <label className="block text-sm">Mô tả<textarea value={description} onChange={e => setDescription(e.target.value)} className={inputClass} /></label>
        <label className="block text-sm">Danh mục<input maxLength={64} value={category} onChange={e => setCategory(e.target.value)} className={inputClass} /></label>
        <label className="block text-sm">Quyền được cấp<textarea rows={5} value={capabilities} onChange={e => setCapabilities(e.target.value)} className={`${inputClass} font-mono`} placeholder={'navigation.close\nuser.getProfile\npayment.createOrder'} /></label>
        <p className="text-xs text-slate-400">Mỗi dòng một capability, hoặc phân cách bằng dấu phẩy. Lưu quyền có hiệu lực ở lần mở Mini App tiếp theo.</p>
        <button className={buttonClass} type="submit">{busy ? 'Đang xử lý...' : 'Lưu thông tin và quyền'}</button>
      </fieldset>
    </form>
    {app && <>
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 flex items-center justify-between gap-4">
        <div><h3 className="font-semibold">{app.status === 'PUBLISHED' ? 'Đang hiển thị' : 'Đang ẩn'}</h3><p className="text-xs text-slate-400 mt-1">Phiên bản đang dùng: {app.activePublishedVersion || 'Chưa upload'}</p></div>
        <button className={buttonClass} disabled={busy || !app.activePublishedVersion} onClick={() => void run(async () => {
          await request(`/${app.id}/visibility`, 'PATCH', { visible: app.status !== 'PUBLISHED' }); await onSaved(app.id);
        }, app.status === 'PUBLISHED' ? 'Đã ẩn Mini App.' : 'Đã hiện Mini App.')}>{app.status === 'PUBLISHED' ? 'Ẩn Mini App' : 'Hiện Mini App'}</button>
      </div>
      <form className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4" onSubmit={e => { e.preventDefault(); void run(async () => {
        await request(`/${app.id}/versions`, 'POST', { version, notes, entryUrl, isAsset, ...(runtimeType === 'schema' ? { schema: JSON.parse(schema) } : {}) });
        await onSaved(app.id); setNotes('');
      }, 'Đã upload và chuyển sang phiên bản mới.'); }}>
        <h3 className="font-semibold">Upload phiên bản mới</h3>
        <p className="text-xs text-slate-400">Phiên bản được dùng ngay, giữ nguyên trạng thái ẩn/hiện. Không cần xét duyệt.</p>
        <fieldset disabled={busy} className="space-y-4">
          <label className="block text-sm">Phiên bản<input required pattern="\d+\.\d+\.\d+" maxLength={32} value={version} onChange={e => setVersion(e.target.value)} className={inputClass} /></label>
          {runtimeType === 'schema' && <>
            <label className="block text-sm">Chọn file schema JSON<input type="file" accept=".json,application/json" className="block mt-2 text-sm" onChange={async e => {
              const file = e.target.files?.[0]; if (!file) return;
              try {
                if (file.size > 1024 * 1024) throw new Error('File JSON tối đa 1 MB');
                const parsed = JSON.parse(await file.text());
                if (!parsed || !Array.isArray(parsed.pages)) throw new Error('File phải là schema JSON có mảng pages');
                setSchema(JSON.stringify(parsed, null, 2)); setError('');
              } catch (err) { setError(err instanceof Error ? err.message : 'Không đọc được file'); }
              e.target.value = '';
            }} /></label>
            <label className="block text-sm">Nội dung schema<textarea required rows={10} value={schema} onChange={e => setSchema(e.target.value)} className={`${inputClass} font-mono`} /></label>
          </>}
          <label className="block text-sm">{runtimeType === 'web' ? 'URL Mini App đã host' : 'Đường dẫn schema runtime'}<input required maxLength={255} value={entryUrl} onChange={e => setEntryUrl(e.target.value)} className={inputClass} placeholder="https://example.com/index.html" /></label>
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={isAsset} onChange={e => setIsAsset(e.target.checked)} />Dùng đường dẫn assets đã đóng gói trong Super App</label>
          <label className="block text-sm">Ghi chú<textarea value={notes} onChange={e => setNotes(e.target.value)} className={inputClass} /></label>
          <button type="submit" className={buttonClass}>{busy ? 'Đang xử lý...' : 'Upload phiên bản'}</button>
        </fieldset>
      </form>
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-3"><h3 className="font-semibold">Các phiên bản đã upload</h3>
        {!app.versions?.length && <p className="text-sm text-slate-400">Chưa có phiên bản.</p>}
        {[...(app.versions || [])].sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt)).map(v => <div key={v.id} className="border-t border-slate-800 pt-3 text-sm">
          <strong>{v.version}</strong>{v.version === app.activePublishedVersion && <span className="text-emerald-400 ml-2">Đang dùng</span>}
          <span className="text-slate-400 ml-3">{new Date(v.createdAt).toLocaleString('vi-VN')}</span>
          {v.reviewNotes && <p className="text-slate-400 mt-1">{v.reviewNotes}</p>}
        </div>)}
      </div>
    </>}
  </div>;
}
